# InfraTrack promotional website

This is the React/Vite promotional website for InfraTrack. It uses Tailwind
design tokens, Lucide React icons, and GSAP/ScrollTrigger for the pinned story.
Map tiles use OpenStreetMap data and require an internet connection. The
glowing markers, phone screens, and report workflow show illustrative sample
data, not live reports.

## Run locally

Use Node.js 20.19 or newer:

```sh
npm install
npm run dev
```

Create a production build with `npm run build`. The generated static site is in
`dist/`; `npm run preview` serves that build locally for review.
