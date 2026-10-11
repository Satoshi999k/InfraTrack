export function startVisiblePolling(
  callback,
  {
    documentRef,
    intervalMs,
    setIntervalFn = setInterval,
    clearIntervalFn = clearInterval,
  },
) {
  let stopped = false;
  let inFlight = false;

  const poll = async () => {
    if (stopped || documentRef.visibilityState === "hidden" || inFlight) return;

    inFlight = true;
    try {
      await callback();
    } finally {
      inFlight = false;
    }
  };

  const handleVisibilityChange = () => {
    if (documentRef.visibilityState !== "hidden") void poll();
  };

  documentRef.addEventListener("visibilitychange", handleVisibilityChange);
  const intervalId = setIntervalFn(() => void poll(), intervalMs);
  void poll();

  return () => {
    stopped = true;
    clearIntervalFn(intervalId);
    documentRef.removeEventListener("visibilitychange", handleVisibilityChange);
  };
}
