# Recipe API Research

Checked on: 2026-03-18

## Goal

Find public APIs or public data sources suitable for a recipe-themed portfolio project with:

- broad enough feature coverage
- manageable usage terms
- low risk of violating provider rules if implemented correctly

This note is a practical summary of the official docs and terms that were reviewed. It is not legal advice.

## Recommended Stack

### Best low-risk portfolio stack

Use:

- TheMealDB for core recipe discovery
- USDA FoodData Central for nutrition data
- Open Food Facts as an optional add-on for barcode and product lookup

This combination gives good coverage while keeping licensing and operational constraints easier to manage than Spoonacular or Edamam.

## Candidate Summary

### 1. TheMealDB

Best for:

- core recipe search and detail pages
- browse by category, area, and ingredient
- random recipe features
- lightweight MVP or portfolio demos

Useful features:

- search meals by name
- lookup meal details by id
- filter by ingredient, category, and area
- random meal endpoint
- meal images and metadata

Important terms:

- API data can be used through the official endpoints.
- Free usage is intended for development projects.
- Free users may not publish apps to an app store unless they become paid subscribers.
- Premium/supporter access is positioned for production-style usage.

Practical verdict:

- Good default choice for a portfolio app.
- Safest path for any public release is to use a paid/supporter key.
- Dataset breadth is limited compared with larger commercial recipe APIs, but still enough for a portfolio.

Notes:

- TheMealDB home page currently states a relatively small dataset size, which is fine for a portfolio but not ideal for a large consumer app.

Official sources:

- https://www.themealdb.com/
- https://www.themealdb.com/api.php
- https://www.themealdb.com/terms_of_use.php

### 2. USDA FoodData Central

Best for:

- ingredient nutrition
- macro and micronutrient lookup
- nutrition panels
- supplementing recipe APIs that lack robust nutrition data

Useful features:

- food search
- food details lookup
- nutrient breakdown
- branded and foundation foods

Important terms:

- Data is released as public domain / CC0.
- API access requires a key.
- Default rate limit is documented at 1,000 requests per hour per IP.

Practical verdict:

- Very safe supplement for a public portfolio project.
- Not a full recipe API, so it works best as a nutrition companion rather than the primary recipe source.

Official source:

- https://fdc.nal.usda.gov/api-guide

### 3. Open Food Facts

Best for:

- barcode scanning
- pantry or grocery features
- allergen and product lookup
- branded food search

Useful features:

- open food product database
- product nutrition and ingredient data
- barcode-based lookup
- image and labeling metadata

Important terms:

- Data reuse is allowed under ODbL.
- Attribution is required.
- Share-alike obligations may apply if the database is combined into another database.
- API consumers should send a custom User-Agent.

Practical verdict:

- Strong optional add-on for product and grocery features.
- Best used as a separate live lookup service.
- Avoid merging Open Food Facts data into a closed proprietary database unless you are prepared to comply with ODbL obligations.

Official sources:

- https://openfoodfacts.github.io/openfoodfacts-server/api/
- https://support.openfoodfacts.org/help/en-gb/12-api-data-reuse/94-are-there-conditions-to-use-the-api

### 4. Spoonacular

Best for:

- feature-rich demo apps
- meal planning
- shopping list workflows
- pantry or "what can I cook" features
- advanced recipe utilities

Useful features:

- recipe search
- ingredient search
- meal planning
- shopping lists
- recipe nutrition
- ingredient substitutions
- price breakdown
- pantry/fridge discovery flows

Important terms:

- Attribution to the original recipe source is required.
- The free plan requires a backlink.
- The terms prohibit using the API to create an app or site meant to provide the same experience as Spoonacular.
- Storage and caching are restricted; long-term bulk copying is not allowed.

Practical verdict:

- Best single API if breadth matters more than licensing simplicity.
- Suitable for a focused portfolio tool, not a generic Spoonacular-style clone.
- Safe usage depends heavily on live fetching, attribution, and respecting storage restrictions.

Implementation note for this project:

- The onboarding flow uses Spoonacular at tap time with title-based search, rather than pre-seeded remote IDs, so the live fetch is tied to the selected carousel recipe title.
- Open Food Facts is used only as optional product context when a curated recipe has matching barcode metadata.
- If Spoonacular does not return a usable match, the app falls back to the curated local recipe detail without adding a separate fallback UX message.

Official sources:

- https://spoonacular.com/food-api
- https://spoonacular.com/food-api/pricing
- https://spoonacular.com/food-api/terms

### 5. Edamam

Best for:

- nutrition-centric apps
- diet and health filtering
- allergy-aware search experiences

Useful features:

- recipe search
- nutrition analysis
- diet and health filters
- meal-planning oriented features

Important terms:

- Usage terms are stricter than the other options above.
- Free usage language is limited to personal or not-for-profit use.
- Attribution to Edamam and source providers is required.
- Archiving, copying, and general data storage are restricted without permission.
- Current public recipe access appears more paid-first than the simpler alternatives.

Practical verdict:

- Not the best default option for a broad public portfolio project.
- More suitable when the project is specifically about nutrition or diet intelligence and can comply with strict attribution and storage rules.

Official sources:

- https://developer.edamam.com/edamam-recipe-api
- https://developer.edamam.com/edamam-docs-recipe-api
- https://developer.edamam.com/signup
- https://developer.edamam.com/attribution

## Final Recommendation

### If the goal is safest public portfolio usage

Use:

- TheMealDB with a paid/supporter key for public release
- USDA FoodData Central for nutrition
- Open Food Facts only as an optional separate lookup service

Why:

- broad enough feature set for a portfolio
- easier compliance than Spoonacular and Edamam
- fewer restrictions on storage and product design when implemented carefully

### If the goal is maximum features from one API

Use Spoonacular only if:

- the app is a focused feature demo rather than a general recipe portal clone
- recipe source attribution is visible
- response storage is kept within their rules

## Suggested Portfolio Features

A solid portfolio app can combine these without unusual licensing risk:

- recipe search by name
- browse by category and cuisine
- filter by ingredient
- random meal discovery
- recipe detail screen
- favorites and collections stored locally
- shopping list stored locally
- nutrition breakdown using USDA data
- barcode or grocery lookup using Open Food Facts

## Compliance Checklist

- Use only official APIs and official endpoints.
- Show attribution where the provider requires it.
- Store only your own user data plus third-party identifiers when possible.
- Avoid building a bulk local mirror of third-party recipe content unless the terms explicitly allow it.
- For Open Food Facts, send a custom User-Agent.
- For Spoonacular and Edamam, be conservative about caching and raw response retention.
- For TheMealDB, use paid/supporter access before any app store release.
