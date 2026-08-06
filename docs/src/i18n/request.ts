import { defaultLocale, isLocale } from '@/lib/i18n';
import { getRequestConfig } from 'next-intl/server';
import english from './messages/en.json';
import polish from './messages/pl.json';

const messages = { en: english, pl: polish };

export default getRequestConfig(async ({ locale, requestLocale }) => {
  const requestedLocale = locale ?? (await requestLocale);
  const resolvedLocale = isLocale(requestedLocale) ? requestedLocale : defaultLocale;

  return {
    locale: resolvedLocale,
    messages: messages[resolvedLocale],
  };
});
