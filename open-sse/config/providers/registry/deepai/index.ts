import type { RegistryEntry } from "../../shared";

export const deepaiProvider: RegistryEntry = {
  id: "deepai",
  alias: "deepai",
  format: "custom",
  baseUrl: "https://api.deepai.org",
  authType: "apikey",
  authHeader: "api-key",
  executor: "default",
  models: [
    { id: "text2img", name: "Text to Image" },
  ],
};
