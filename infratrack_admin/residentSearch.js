export function filterResidents(residents, searchTerm) {
  const query = String(searchTerm ?? "").trim().toLowerCase();
  if (!query) return residents;

  return residents.filter((resident) =>
    [resident.name, resident.email, resident.barangay]
      .some((value) => String(value ?? "").toLowerCase().includes(query)),
  );
}
