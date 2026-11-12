import english from "@tazkiyah/i18n/messages/en/common.json";
import urdu from "@tazkiyah/i18n/messages/ur/common.json";
import { institute } from "./markaz-al-azeem";
import { homeFactKeys, type HomeFacts } from "./site-pages";

export const defaultHomeFacts = Object.fromEntries(
  homeFactKeys.map((key) => [
    key,
    {
      value: institute.figures[key],
      label: { en: english.community[key].stat, ur: urdu.community[key].stat },
    },
  ]),
) as HomeFacts;
