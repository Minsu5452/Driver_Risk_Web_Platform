import { Link } from "react-router-dom";
import { CONTACT_EMAIL, CONTACT_PHONE, COPYRIGHT } from "@/constants/site";

import logoFooterImg from "/assets/images/footer_logo.png";
import logoFooterImgMobile from "/assets/images/ts_logo.png";
import bannerImg_01 from "/assets/images/banner_w_01.png";
import bannerImgMobile_01 from "/assets/images/banner_m_01.png";
import bannerImg_02 from "/assets/images/banner_w_02.png";
import bannerImgMobile_02 from "/assets/images/banner_m_02.png";

function EgovFooter() {
  return (
    <div className="footer">
      <div className="inner">
        <h1>
          <Link to="/">
            <img className="w" src={logoFooterImg} alt="" />
            <img className="m" src={logoFooterImgMobile} alt="" />
          </Link>
        </h1>
        <div className="info">
          <p>
            문의 메일 : {CONTACT_EMAIL}{" "}
            <span className="m_hide">|</span>
            <br className="m_show" /> 문의 전화 : {CONTACT_PHONE}
          </p>
          <p className="copy">
            &copy; {COPYRIGHT}
          </p>
        </div>
        <div className="right_col">
          <Link to="/">
            <img className="w" src={bannerImg_01} alt="" />
            <img className="m" src={bannerImgMobile_01} alt="" />
          </Link>
          <Link to="/">
            <img className="w" src={bannerImg_02} alt="" />
            <img className="m" src={bannerImgMobile_02} alt="" />
          </Link>
        </div>
      </div>
    </div>
  );
}

export default EgovFooter;
