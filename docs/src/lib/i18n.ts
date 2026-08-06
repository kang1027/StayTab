import { defineI18n } from 'fumadocs-core/i18n';

export const defaultLocale = 'en';

export const i18n = defineI18n({
  defaultLanguage: defaultLocale,
  languages: [defaultLocale, 'pl'],
  hideLocale: 'default-locale',
  parser: 'dir',
  fallbackLanguage: null,
});

export type Locale = (typeof i18n.languages)[number];

export function isLocale(value: string | undefined): value is Locale {
  return value !== undefined && i18n.languages.some((locale) => locale === value);
}

/** Split the optional catch-all route into its locale and content slug. */
export function resolveLocalePath(path: string[] | undefined): {
  locale: Locale;
  slugs: string[] | undefined;
} {
  const candidate = path?.[0];
  if (candidate !== defaultLocale && isLocale(candidate)) {
    return { locale: candidate, slugs: path?.slice(1) };
  }

  return { locale: defaultLocale, slugs: path };
}

export function localizedSegments(locale: string | undefined, segments: string[]): string[] {
  return locale && locale !== defaultLocale ? [locale, ...segments] : segments;
}
