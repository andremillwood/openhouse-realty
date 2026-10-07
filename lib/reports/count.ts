/** Keep independent report failures visible without presenting them as zero. */
export async function reportCount(query: PromiseLike<{count: number | null; error: unknown}>): Promise<number | null> {
 try {
  const result = await query;
  return !result.error && typeof result.count === 'number' && Number.isSafeInteger(result.count) && result.count >= 0 ? result.count : null;
 } catch {
  return null;
 }
}
