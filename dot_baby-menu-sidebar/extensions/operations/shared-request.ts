export function sharedRequest<T>(load: () => Promise<T>) {
  let current: Promise<T> | undefined;

  return {
    get(): Promise<T> {
      if (current) return current;
      const pending = Promise.resolve().then(load);
      current = pending;
      const clear = () => {
        if (current === pending) current = undefined;
      };
      void pending.then(clear, clear);
      return pending;
    },
    invalidate(): void {
      current = undefined;
    },
  };
}
