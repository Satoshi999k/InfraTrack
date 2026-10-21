export function filterResidents(residents, searchTerm) {
  const query = String(searchTerm ?? "").trim().toLowerCase();
  if (!query) return residents;

  return residents.filter((resident) =>
    [resident.name, resident.email, resident.barangay]
      .some((value) => String(value ?? "").toLowerCase().includes(query)),
  );
}

export function paginateResidents(residents, requestedPage, pageSize = 10) {
  const safePageSize = Math.max(1, Math.floor(Number(pageSize) || 10));
  const pageCount = Math.max(1, Math.ceil(residents.length / safePageSize));
  const page = Math.min(
    pageCount,
    Math.max(1, Math.floor(Number(requestedPage) || 1)),
  );
  const startIndex = (page - 1) * safePageSize;

  return {
    items: residents.slice(startIndex, startIndex + safePageSize),
    page,
    pageCount,
    start: residents.length ? startIndex + 1 : 0,
    end: Math.min(startIndex + safePageSize, residents.length),
    total: residents.length,
  };
}
