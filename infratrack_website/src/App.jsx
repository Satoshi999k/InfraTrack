import { useLayoutEffect, useMemo, useRef } from "react";
import parse from "html-react-parser";
import siteContent from "./site-content.html?raw";
import "./styles.css";

function requiredMarkup(document, selector) {
  const element = document.querySelector(selector);
  if (!element) {
    throw new Error(`The website template is missing its ${selector} section.`);
  }
  return element.outerHTML;
}

function getPageSections() {
  const template = new DOMParser().parseFromString(siteContent, "text/html");

  return {
    skipLink: requiredMarkup(template, ".skip"),
    navigation: `${requiredMarkup(template, "#nav")}${requiredMarkup(template, "#menu")}`,
    story: `${requiredMarkup(template, "#stage")}${requiredMarkup(template, "#rm")}`,
    closing: requiredMarkup(template, "#final"),
    footer: requiredMarkup(template, ".footer"),
  };
}

function ContentFragment({ markup }) {
  return parse(markup);
}

function Navbar({ markup }) {
  return <ContentFragment markup={markup} />;
}

function HeroScene({ markup }) {
  return <ContentFragment markup={markup} />;
}

function FinalCTA({ markup }) {
  return <ContentFragment markup={markup} />;
}

function SiteFooter({ markup }) {
  return <ContentFragment markup={markup} />;
}

export default function App() {
  const siteRef = useRef(null);
  const sections = useMemo(getPageSections, []);

  useLayoutEffect(() => {
    let disposed = false;
    let cleanup;

    import("./animations.js")
      .then(({ initializeSite }) => {
        if (!disposed) cleanup = initializeSite(siteRef.current);
      })
      .catch((error) => {
        console.error("Unable to initialize the InfraTrack website.", error);
      });

    return () => {
      disposed = true;
      cleanup?.();
    };
  }, []);

  return (
    <div
      className="site-root min-h-screen bg-concrete font-ui text-ink"
      ref={siteRef}
    >
      <ContentFragment markup={sections.skipLink} />
      <Navbar markup={sections.navigation} />
      <main id="main">
        <HeroScene markup={sections.story} />
        <FinalCTA markup={sections.closing} />
      </main>
      <SiteFooter markup={sections.footer} />
    </div>
  );
}
