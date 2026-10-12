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
    name: "Water supply",
    description: "Water access, supply interruptions, and pipe leaks",
    categories: ["water", "water supply"],
    keywords: [/\bwater supply\b/i, /\bwater service\b/i, /\bwater interruption\b/i, /\bwater shortage\b/i, /\bwater leak\b/i, /\bwater pipes?\b/i, /\bpipes?\b/i, /\bpotable water\b/i, /\bfaucets?\b/i],
  },
  {
    name: "Lighting & electricity",
    description: "Streetlights, electrical service, and exposed wiring",
    categories: ["lighting", "electricity"],
    keywords: [/\bstreet ?lights?\b/i, /\blights?\b/i, /\blighting\b/i, /\belectric(?:ity|al)?\b/i, /\bpower outage\b/i, /\bwiring\b/i, /\blamp ?posts?\b/i, /\bdark(?:ness)?\b/i, /\bnight(?:time)?\b/i, /\bbulbs?\b/i, /\billumination\b/i],
  },
  {
    name: "Waste & sanitation",
    description: "Waste collection, dumping, and sanitation concerns",
    categories: ["waste", "sanitation", "garbage"],
    keywords: [/\bgarbage\b/i, /\bwaste\b/i, /\btrash\b/i, /\bdumping\b/i, /\bsewage\b/i, /\bsanitation\b/i, /\bseptic\b/i],
  },
  {
    name: "Public facilities",
    description: "Community buildings, parks, and public-use facilities",
    categories: ["public facilities", "facilities"],
    keywords: [/\bschool\b/i, /\bclinic\b/i, /\bhealth cent(?:er|re)\b/i, /\bpark\b/i, /\bpublic market\b/i, /\bbarangay hall\b/i, /\bpublic facilit(?:y|ies)\b/i],
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
