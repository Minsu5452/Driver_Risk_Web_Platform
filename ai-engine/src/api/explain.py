import logging
import math
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List

import pandas as pd
from fastapi import APIRouter, HTTPException

from src.core.constants import EXPLAIN_BATCH_WORKERS, EXPLAIN_BATCH_LIMIT, EXPLAIN_TIMEOUT
from src.inference.rank1_engine import explain_dataframe
from src.schemas import DriverInput

logger = logging.getLogger("ai-engine")

router = APIRouter()


def sanitize_floats(obj):
    if isinstance(obj, float):
        if math.isnan(obj) or math.isinf(obj):
            return 0.0
        return obj
    elif isinstance(obj, dict):
        return {k: sanitize_floats(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [sanitize_floats(v) for v in obj]
    return obj


def _explain_single(inp: DriverInput) -> dict:
    """단건 SHAP 설명 (배치에서도 재사용)."""
    domain = inp.domain
    data = inp.features.copy()
    data.update(
        {
            "Test_id": inp.Test_id,
            "TestDate": inp.TestDate,
            "Age": inp.Age,
            "PrimaryKey": inp.PrimaryKey,
        }
    )

    df = pd.DataFrame([data])
    explanation = explain_dataframe(domain, df, detailed=False)

    shap_vals = explanation.get("shap_values", [[]])
    if isinstance(shap_vals, list) and len(shap_vals) > 0:
        if isinstance(shap_vals[0], list):
            shap_vals = shap_vals[0]
    elif hasattr(shap_vals, "tolist"):
        shap_vals = shap_vals.tolist()
        if isinstance(shap_vals[0], list):
            shap_vals = shap_vals[0]

    feature_names = explanation.get("feature_names", [])
    formatted_shap = [
        {"feature": name, "value": float(val), "code": name}
        for name, val in zip(feature_names, shap_vals)
    ]
    formatted_shap.sort(key=lambda x: abs(x["value"]), reverse=True)

    return sanitize_floats(
        {
            "Test_id": inp.Test_id,
            "PrimaryKey": inp.PrimaryKey,
            "shap_values": formatted_shap,
            "base_value": explanation.get("base_value", 0.0),
            "feature_names": feature_names,
        }
    )


@router.post("/explain")
def explain(inp: DriverInput):
    try:
        return _explain_single(inp)
    except Exception as e:
        logger.exception(f"Error explaining: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/explain/batch")
def explain_batch(inputs: List[DriverInput]):
    """여러 운전자 SHAP 일괄 계산 (ThreadPoolExecutor 병렬). 프론트에서 50건씩 청크 호출."""
    if len(inputs) > EXPLAIN_BATCH_LIMIT:
        raise HTTPException(status_code=400, detail=f"1회 최대 {EXPLAIN_BATCH_LIMIT}건입니다. 프론트에서 청크 분할해주세요.")

    results = [None] * len(inputs)
    errors = []

    with ThreadPoolExecutor(max_workers=min(EXPLAIN_BATCH_WORKERS, len(inputs) or 1)) as pool:
        futures = {pool.submit(_explain_single, inp): i for i, inp in enumerate(inputs)}
        for future in as_completed(futures):
            idx = futures[future]
            try:
                results[idx] = future.result(timeout=EXPLAIN_TIMEOUT)
            except Exception as e:
                logger.warning(f"Batch explain error [{idx}]: {e}")
                errors.append({"index": idx, "Test_id": inputs[idx].Test_id, "error": str(e)})

    return {"results": [r for r in results if r is not None], "errors": errors}
