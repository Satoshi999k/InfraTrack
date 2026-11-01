export function shouldSeedDemoData(environment) {
  const enabled =
    String(environment.SEED_DEMO_DATA || "").toLowerCase() === "true";
  if (
    enabled &&
    String(environment.NODE_ENV || "").toLowerCase() === "production"
  ) {
    throw new Error("SEED_DEMO_DATA cannot be enabled in production.");
  }
  return enabled;
}
