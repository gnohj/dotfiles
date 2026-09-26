const listeners = new Set<() => void>();

export function subscribeToOperationsRefresh(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function refreshOperations(): void {
  for (const listener of listeners) listener();
}
