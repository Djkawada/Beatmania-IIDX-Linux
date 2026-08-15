import {
  shopgetname,
  shopgetconvention,
  shopsavename,
  shopgetclosingtime,
} from "./handlers/IIDXshop";
import {
  pccommon,
  pcoldget,
  pcreg,
  pcget,
  pcsave,
  pctakeover,
  pcgetname,
  pcvisit,
  pcgetlanegacha,
} from "./handlers/IIDXpc";
import {
  musicreg,
  musicgetrank,
  musicappoint,
  musiccrate,
  musicretry,
  musicarenacpu,
} from "./handlers/IIDXmusic";
import { systeminfo } from "./handlers/IIDXgamesystem";
import { graderaised } from "./handlers/IIDXgrade";
import { ShopRanking_list } from "./data/settingslist";
import { exportScoreData, updateProfileSettings, updateRivalSettings } from "./handlers/webui";

export function register() {
  if (CORE_VERSION_MAJOR <= 1 && CORE_VERSION_MINOR < 31) {
    console.error(
      "The current version of Asphyxia Core is not supported. Requires version '1.31' or later."
    );
    return;
  }

  R.Contributor("sol#1207", "https://twitter.com/0x1F5");

  // music (array) //
  R.Config("ShopRanking", {
    type: "string",
    default: "PersonalBest",
    options: ShopRanking_list,
  });

  // pccommon (integer) //
  R.Config("BeatPhase", {
    name: "Beat #",
    type: "integer",
    default: 3,
  });
  R.Config("ExpertPhase", {
    name: "Expert Phase",
    type: "integer",
    default: 1,
  });
  R.Config("ExpertSecretPhase", {
    name: "Expert Secret Phase",
    type: "integer",
    default: 2,
  });
  R.Config("BossPhase", {
    name: "Boss Phase",
    type: "integer",
    default: 1,
  });
  R.Config("SystemVoicePhase", {
    name: "System Voice Phase",
    type: "integer",
    default: 1,
  });
  R.Config("ExtraBossPhase", {
    name: "Extra Boss Phase",
    type: "integer",
    default: 1,
  });
  R.Config("Event1Phase", {
    name: "Event Phase",
    type: "integer",
    default: 1,
  });

  // systemInfo (integer) //
  R.Config("Event1InternalPhase", {
    name: "Event Internal Phase",
    type: "integer",
    default: 1,
  });

  // pccommon (string) //
  R.Config("MovieUpload", {
    name: "Movie Upload URL",
    type: "string",
    default: "http://localhost/"
  });

  R.WebUIEvent("updateIIDXProfileSettings", updateProfileSettings);
  R.WebUIEvent("updateIIDXRivalSettings", updateRivalSettings);
  R.WebUIEvent("exportScoreData", exportScoreData);

  R.GameCode("LDJ");
  R.GameCode("TDJ"); // This is not used in [TDJ mode] but has been added just in case. //

  const MultiRoute = (method: string, handler: EPR | boolean) => {
    // Helper for register multiple versions.
    R.Route(`IIDX27${method}`, handler);
    R.Route(`IIDX28${method}`, handler);
    R.Route(`IIDX29${method}`, handler);
    R.Route(`IIDX30${method}`, handler);
    R.Route(`IIDX31${method}`, handler);
    R.Route(`IIDX32${method}`, handler);
    R.Route(`IIDX33${method}`, handler);
  };

  //pc
  MultiRoute("pc.get", pcget);
  MultiRoute("pc.reg", pcreg);
  MultiRoute("pc.lcommon", true);
  MultiRoute("pc.save", pcsave);
  MultiRoute("pc.save2pp", true);
  MultiRoute("pc.getname", pcgetname);
  MultiRoute("pc.locaend", true);
  MultiRoute("pc.common", pccommon);
  MultiRoute("pc.takeover", pctakeover);
  MultiRoute("pc.playstart", true); // no-card (entry) //
  MultiRoute("pc.playend", true); // no-card (game-over) //
  MultiRoute("pc.delete", true);
  MultiRoute("pc.visit", pcvisit);
  MultiRoute("pc.shopregister", true);
  MultiRoute("pc.oldget", pcoldget);
  MultiRoute("pc.eaappliresult", true);
  MultiRoute("pc.eaappliexpert", true);
  MultiRoute("pc.logout", true);
  MultiRoute("pc.qrreward", true);
  MultiRoute("pc.qrcompe", true);
  MultiRoute("pc.qrfollow", true);
  MultiRoute("pc.consumeLaneGachaTicket", true);
  MultiRoute("pc.drawLaneGacha", true);
  MultiRoute("pc.getLaneGachaTicket", pcgetlanegacha);
  MultiRoute("pc.getCompeInfo", true);
  MultiRoute("pc.compeOrganize", true);
  MultiRoute("pc.compeEntry", true);
  MultiRoute("pc.compeSearch", true);
  MultiRoute("pc.setBestresult", true);

  //music
  MultiRoute("music.getrank", musicgetrank);
  MultiRoute("music.getranksub", true);
  MultiRoute("music.lplay", true);
  MultiRoute("music.play", true); // no-card (result) //
  MultiRoute("music.reg", musicreg);
  MultiRoute("music.crate", musiccrate);
  MultiRoute("music.appoint", musicappoint);
  MultiRoute("music.nosave", true);
  MultiRoute("music.arenaCPU", musicarenacpu);
  MultiRoute("music.movieinfo", true);
  MultiRoute("music.retry", musicretry);

  //grade
  MultiRoute("grade.raised", graderaised);

  //shop
  MultiRoute("shop.sentinfo", true);
  MultiRoute("shop.keepalive", true);
  MultiRoute("shop.savename", shopsavename);
  MultiRoute("shop.getname", shopgetname);
  MultiRoute("shop.setconvention", true);
  MultiRoute("shop.getconvention", shopgetconvention);
  MultiRoute("shop.sendpcbdetail", true); 
  MultiRoute("shop.sendescapepackageinfo", true);  
  MultiRoute("shop.recoveryfilelog", true);
  MultiRoute("shop.getclosingtime", shopgetclosingtime);
  MultiRoute("shop.saveclosingtime", true);
  
  //ranking
  MultiRoute("ranking.entry", true);
  MultiRoute("ranking.oentry", true);
  MultiRoute("ranking.getranker", true); 
  MultiRoute("ranking.classicentry", true);
  MultiRoute("ranking.conventionentry", true);

  //lobby
  MultiRoute("lobby.entry", true);
  MultiRoute("lobby.update", true);
  MultiRoute("lobby.delete", true);
  MultiRoute("lobby.bplbattle_entry", true);
  MultiRoute("lobby.bplbattle_update", true);
  MultiRoute("lobby.bplbattle_delete", true);

  //streaming
  MultiRoute("streaming.common", true);
  MultiRoute("streaming.getcm", true);

  //gameSystem
  MultiRoute("gameSystem.systemInfo", systeminfo);
  MultiRoute("gameSystem.serverTime", true);


  // facility
  R.Route("facility.get", (info, data, send) => {
    return send.object({
      facility: {
        location: {
          id: "ea",
          country: "JP",
          region: "1",
          name: "CORE",
          type: K.ITEM("u8", 0),
          countryname: "JAPAN",
          countryjname: "日本",
          regionname: "CORE",
          regionjname: "CORE",
          customercode: "AXUSR",
          companycode: "AXCPY",
          latitude: K.ITEM("s32", 6666),
          longitude: K.ITEM("s32", 6666),
          accuracy: K.ITEM("u8", 0),
        },
        line: {
          id: ".",
          class: K.ITEM("u8", 0),
        },
        portfw: {
          globalip: K.ITEM("ip4", "127.0.0.1"),
          globalport: K.ITEM("u16", 5700),
          privateport: K.ITEM("u16", 5700),
        },
        public: {
          flag: K.ITEM("u8", 1),
          name: "UNKNOWN",
          latitude: "0",
          longitude: "0",
        },
        share: {
          eacoin: {
            notchamount: K.ITEM("s32", 0),
            notchcount: K.ITEM("s32", 0),
            supplylimit: K.ITEM("s32", 100000),
          },
          url: {
            eapass: "http://127.0.0.1:8083/",
            arcadefan: "http://127.0.0.1:8083/",
            konaminetdx: "http://127.0.0.1:8083/",
            konamiid: "http://127.0.0.1:8083/",
            eagate: "http://127.0.0.1:8083/",
          },
        },
      },
    });
  });

  R.Unhandled();
}
