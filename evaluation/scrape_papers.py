from playwright.sync_api import sync_playwright
import json
from urllib.parse import urljoin
import re
from pydantic import BaseModel, HttpUrl
from typing import List

BASE = "https://dl.acm.org"

CONF_NAME = ['ICSE', 'FSE', 'ASE', 'ISSTA']
NON_MAIN = ['SEIS', 'NIER', 'SEET', 'Companion']
class Paper(BaseModel):
    title: str
    paper_url: HttpUrl
    artifact_url: HttpUrl
    conf: str
    year: int
    badges: List[str]
    authors: List[str]
    use_docker: bool
    use_gpu: bool
    use_api: bool
    details: str

def scrape(start_url: str, year: int):
    """Return list of papers by crawling all pages from start_url."""
    results = []
    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=False, devtools=True)
        page = browser.new_page()
        page.goto(start_url, timeout=60000)
        page.wait_for_load_state("networkidle")

        while True:
            containers = page.locator("li.search__item.issue-item-container")
            for i in range(containers.count()):
                item = containers.nth(i)
                # title
                title_el = item.locator("h3.issue-item__title a").first
                title = title_el.inner_text().strip()
                href = title_el.get_attribute("href")
                link = urljoin(BASE, href) if href else None
                # authors
                authors = item.locator("ul.rlist--inline.loa li a").all_inner_texts()
                # badges
                badge_els = item.locator("div.badges a.simple-tooltip__block--b")
                badges = [
                    badge_els.nth(j).get_attribute("data-title")
                    for j in range(badge_els.count())
                ]
                # conf & year
                details = item.locator("div.issue-item__detail")\
                               .inner_text().strip().replace("\n", " ")
                if any(sub in details for sub in NON_MAIN):
                    continue
                conf = next((c for c in CONF_NAME if c in details), None)
                results.append({
                    "title": title,
                    "paper_url": link,
                    "artifact_url": '',
                    "conf": conf,
                    "year": year,
                    "authors": authors,
                    "badges": badges,
                    "details": details,
                    # Placeholder values
                    "use_docker": False,
                    "use_gpu": False,
                    "use_api": False,
                })

            # next‐page check
            next_links = page.locator('a[rel="next"]')
            if next_links.count() == 0:
                break
            next_links.first.click()
            page.wait_for_load_state("networkidle")

        browser.close()
    return results


def scrape_dlacm():
    all_data = []
    year = 2024
    START_ICSE = f"https://dl.acm.org/action/doSearch?fillQuickSearch=false&target=advanced&expand=dl&field1=ContentGroupTitle&text1=ICSE&ArtifactAnd=118213&startPage=0&pageSize=300&AfterYear={year}&BeforeYear={year}"
    START_FSE = f"https://dl.acm.org/action/doSearch?fillQuickSearch=false&target=advanced&expand=dl&ArtifactAnd=118213&AllField=ContentGroupTitle%3A%28FSE%29+OR+AllField%3A%28PACMSE%29&pageSize=200&AfterYear={year}&BeforeYear={year}"
    START_ASE = f"https://dl.acm.org/action/doSearch?fillQuickSearch=false&target=advanced&expand=dl&field1=ContentGroupTitle&text1=ASE&ArtifactAnd=118213&startPage=0&pageSize=200&AfterYear={year}&BeforeYear={year}"
    START_ISSTA = f"https://dl.acm.org/action/doSearch?fillQuickSearch=false&target=advanced&expand=dl&field1=ContentGroupTitle&text1=ISSTA&ArtifactAnd=118213&startPage=0&pageSize=200&AfterYear={year}&BeforeYear={year}"

    for url in [START_ICSE, START_FSE, START_ASE, START_ISSTA]:
        all_data.extend(scrape(url, year))

    print(f"Scraped total {len(all_data)} papers")
    with open("results.json", "w", encoding="utf-8") as f:
        json.dump(all_data, f, indent=2)


if __name__ == "__main__":
    scrape_dlacm()