export function BrandMark({ className = "" }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M12 22s8-6.2 8-13a8 8 0 1 0-16 0c0 6.8 8 13 8 13Z" />
      <path d="M12 6.5v5M9.5 9h5" />
    </svg>
  );
}
