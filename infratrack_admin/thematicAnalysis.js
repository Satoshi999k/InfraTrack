const themes = [
  {
    name: "Roads & transportation",
    description: "Road surfaces, access, sidewalks, and bridges",
    categories: ["road", "roads", "transportation"],
    keywords: [/\broad\b/i, /\bpotholes?\b/i, /\bsidewalks?\b/i, /\bbridges?\b/i, /\bpavement\b/i, /\basphalt\b/i, /\btraffic\b/i],
  },
  {
    name: "Drainage & flooding",
    description: "Drainage systems, canals, and flood-prone areas",
    categories: ["drainage", "flood control"],
    keywords: [/\bdrain(?:age)?\b/i, /\bflood(?:ing|ed)?\b/i, /\bcanals?\b/i, /\bculverts?\b/i, /\bwaterlog(?:ging|ged)?\b/i, /\bstormwater\b/i],
  },
  {
    name: "Public buildings",
    description: "Public buildings such as barangay halls, schools, and public facilities",
    categories: ["public building", "public buildings"],
    keywords: [/\bpublic build(?:ing|ings)\b/i, /\bbarangay hall\b/i, /\bpublic school\b/i, /\bpublic market\b/i, /\bhealth cent(?:er|re)\b/i, /\bmunicipal building\b/i],
  },
  {
    name: "Streetlights",
    description: "Streetlights and public-road lighting",
    categories: ["lighting", "streetlight", "streetlights"],
    keywords: [/\bstreet ?lights?\b/i, /\bstreet ?lighting\b/i, /\blamp ?posts?\b/i, /\bdark(?:ness)?\b/i, /\bnight(?:time)?\b/i, /\bbulbs?\b/i, /\billumination\b/i],
  },
  {
    name: "Electric poles",
    description: "Electric poles, utility poles, and overhead public power lines",
    categories: ["electric pole", "electric poles"],
    keywords: [/\belectric(?:ity|al)? poles?\b/i, /\butility poles?\b/i, /\bpower poles?\b/i, /\boverhead (?:power )?lines?\b/i, /\bpower lines?\b/i, /\bexposed wiring\b/i],
  },
];

function scoreTheme(report, theme) {
  const category = String(report.category || "").trim().toLowerCase();
  const text = `${report.title || ""} ${report.description || ""}`;
  const categoryMatch = theme.categories.some((name) => category === name || category.includes(name));
  const keywordMatches = theme.keywords.reduce((count, pattern) => count + Number(pattern.test(text)), 0);
  return Number(categoryMatch) * 3 + keywordMatches;
}

export function analyzeReportThemes(reports) {
  const counts = new Map();

  for (const report of reports) {
    const match = themes
      .map((theme, index) => ({ theme, index, score: scoreTheme(report, theme) }))
      .filter((item) => item.score > 0)
      .sort((left, right) => right.score - left.score || left.index - right.index)[0];
    const name = match?.theme.name || "Other infrastructure concerns";
    counts.set(name, (counts.get(name) || 0) + 1);
  }

  return [...counts.entries()]
    .map(([name, count]) => ({
      name,
      count,
      percentage: reports.length ? Math.round((count / reports.length) * 100) : 0,
      description: themes.find((theme) => theme.name === name)?.description || "Reports without a matching infrastructure theme",
    }))
    .sort((left, right) => right.count - left.count || left.name.localeCompare(right.name));
}
