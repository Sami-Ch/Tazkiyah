/**
 * Map of a published address. The query is the institute’s own address string,
 * so the pin is the map provider’s result, not a coordinate typed into the code.
 */
export function AddressMap({ query, title }: { query: string; title: string }) {
  const src = `https://maps.google.com/maps?${new URLSearchParams({
    q: query,
    z: "16",
    output: "embed",
  })}`;
  return (
    <div className="map-frame">
      <iframe title={title} src={src} loading="lazy" referrerPolicy="no-referrer" />
    </div>
  );
}
