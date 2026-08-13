import { llms } from 'fumadocs-core/source';

import { canonicalizeLLMLinks, source } from '@/lib/source';

export const revalidate = false;

export function GET() {
  return new Response(canonicalizeLLMLinks(llms(source).index()));
}
