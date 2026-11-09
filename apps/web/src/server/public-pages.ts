import { headers } from "next/headers";
import { cache } from "react";
import { getPublishedSitePages } from "./auth";

export const readPublishedPages = cache(async () =>
  getPublishedSitePages(new Headers(await headers())),
);
