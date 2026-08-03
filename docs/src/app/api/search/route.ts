import { source } from '@/lib/source';
import { createFromSource } from 'fumadocs-core/search/server';

// Static export: `staticGET` bakes the whole index into one JSON file at build
// time and the client searches it in-browser. The dynamic `GET` would need a
// running server, which this deployment does not have.
export const { staticGET: GET } = createFromSource(source);

export const revalidate = false;
