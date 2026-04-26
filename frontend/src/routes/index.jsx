import { useEffect, useRef } from "react";
import { Navigate, Routes, Route, useLocation } from "react-router-dom";

import URL from "@/constants/url";

import EgovHeader from "@/components/EgovHeader";
import EgovFooter from "@/components/EgovFooter";
import EgovError from "@/components/EgovError";
import EgovMain from "@/pages/main/EgovMain";
import NiaDashboard from "@/pages/nia/NiaDashboard";
import NiaList from "@/pages/nia/NiaList";
import NiaDiagnosis from "@/pages/nia/NiaDiagnosis";
import NiaAnalysis from "@/pages/nia/NiaAnalysis";
import NiaDownload from "@/pages/nia/NiaDownload";
import AdminLogin from "@/pages/admin/AdminLogin";
import AdminDashboard from "@/pages/admin/AdminDashboard";
import RequireAdmin from "@/components/RequireAdmin";
import useAnalysisStore from "@/store/useAnalysisStore";

const RequireUpload = ({ children }) => {
  const { isUploaded } = useAnalysisStore();
  if (!isUploaded) {
    return <Navigate to={URL.MAIN} replace />;
  }
  return children;
};

const RootRoutes = () => {
  const location = useLocation();
  const pageRef = useRef(null);

  useEffect(() => {
    const el = pageRef.current;
    if (el) {
      el.classList.remove('page-content');
      void el.offsetWidth;
      el.classList.add('page-content');
    }
  }, [location.pathname]);

  return (
    <>
      <EgovHeader />
      <div ref={pageRef} className="page-content">
        <Routes>
          <Route path="/" element={<EgovMain />} />
          <Route path={URL.MAIN} element={<EgovMain />} />
          <Route path={URL.ERROR} element={<EgovError />} />

          <Route path={URL.NIA_DASHBOARD} element={<RequireUpload><NiaDashboard /></RequireUpload>} />
          <Route path={URL.NIA_LIST} element={<RequireUpload><NiaList /></RequireUpload>} />
          <Route path={URL.NIA_DIAGNOSIS} element={<RequireUpload><NiaDiagnosis /></RequireUpload>} />
          <Route path={URL.NIA_ANALYSIS} element={<RequireUpload><NiaAnalysis /></RequireUpload>} />
          <Route path={URL.NIA_DOWNLOAD} element={<RequireUpload><NiaDownload /></RequireUpload>} />

          <Route path={URL.ADMIN_LOGIN} element={<AdminLogin />} />
          <Route path={URL.ADMIN_DASHBOARD} element={<RequireAdmin><AdminDashboard /></RequireAdmin>} />
        </Routes>
      </div>

      <EgovFooter />
    </>
  );
};

export default RootRoutes;