import { useCallback, useEffect, useRef } from "react";

const BOTTOM_THRESHOLD = 40;

/**
 * Auto-scroll a container to the bottom when new content arrives,
 * but only if the user is already scrolled near the bottom.
 * If they've scrolled up to read something, respect that.
 */
export function useAutoScroll<T extends HTMLElement>(deps: unknown[]) {
  const containerRef = useRef<T>(null);
  const isFollowingRef = useRef(true);

  const scrollToBottom = useCallback(() => {
    const el = containerRef.current;
    if (!el) return;
    el.scrollTop = el.scrollHeight;
  }, []);

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;

    const onScroll = () => {
      const distanceFromBottom =
        el.scrollHeight - el.scrollTop - el.clientHeight;
      isFollowingRef.current = distanceFromBottom <= BOTTOM_THRESHOLD;
    };

    el.addEventListener("scroll", onScroll, { passive: true });
    return () => el.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    if (isFollowingRef.current) {
      scrollToBottom();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  return containerRef;
}
