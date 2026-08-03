import {
  configSections,
  objectKey,
  sectionSlug,
  type ConfigKey,
  type SchemaFragment,
} from '@/lib/config-reference';

/** `50…150`, `9 items`, or nothing when the type is unconstrained. */
function constraint(f: SchemaFragment): string | null {
  if (f.minimum !== undefined && f.maximum !== undefined) return `${f.minimum}…${f.maximum}`;
  if (f.minItems !== undefined && f.minItems === f.maxItems) return `exactly ${f.minItems} items`;
  return null;
}

function Type({ fragment }: { fragment: SchemaFragment }) {
  const range = constraint(fragment);
  return (
    <>
      <code>{fragment.type ?? 'any'}</code>
      {range ? <span className="text-fd-muted-foreground"> {range}</span> : null}
    </>
  );
}

/** Allowed values as a definition list, keeping each value next to its UI label. */
function Values({ fragment }: { fragment: SchemaFragment }) {
  if (!fragment.enum) return null;
  return (
    <ul className="my-1 list-none space-y-0.5 p-0">
      {fragment.enum.map((value, i) => (
        <li key={value} className="p-0">
          <code>{JSON.stringify(value)}</code>
          {fragment.enumDescriptions?.[i] ? (
            <span className="text-fd-muted-foreground"> — {fragment.enumDescriptions[i]}</span>
          ) : null}
        </li>
      ))}
    </ul>
  );
}

function KeyRow({ entry }: { entry: ConfigKey }) {
  return (
    <tr>
      <td className="align-top whitespace-nowrap">
        {/* Anchor target for the generated table of contents. */}
        <code id={entry.name} className="scroll-mt-24">
          {entry.name}
        </code>
      </td>
      <td className="align-top whitespace-nowrap">
        <Type fragment={entry.fragment} />
      </td>
      <td className="align-top whitespace-nowrap">
        {entry.default ? <code>{entry.default}</code> : <span aria-hidden>—</span>}
      </td>
      <td className="align-top">
        {entry.fragment.description}
        <Values fragment={entry.fragment} />
      </td>
    </tr>
  );
}

/** Every grouped scalar/array key, as one table per section. */
export function ConfigReference() {
  return (
    <>
      {configSections().map((section) => (
        <section key={section.title}>
          <h2 id={sectionSlug(section.title)}>{section.title}</h2>
          <p>{section.blurb}</p>
          <table>
            <thead>
              <tr>
                <th>Key</th>
                <th>Type</th>
                <th>Default</th>
                <th>Description</th>
              </tr>
            </thead>
            <tbody>
              {section.keys.map((entry) => (
                <KeyRow key={entry.name} entry={entry} />
              ))}
            </tbody>
          </table>
        </section>
      ))}
    </>
  );
}

/**
 * One array-of-objects key: its own description plus a table of the fields an
 * element may carry. Required fields are marked; everything else is optional and
 * falls back to the global setting of the same name.
 */
export function ConfigObject({ name }: { name: string }) {
  const entry = objectKey(name);
  const item = entry.fragment.items;
  const properties = item?.properties ?? {};
  const required = new Set(item?.required ?? []);
  const names = Object.keys(properties).sort(
    (a, b) => Number(required.has(b)) - Number(required.has(a)) || a.localeCompare(b),
  );

  return (
    <>
      <p>{entry.fragment.description}</p>
      <table>
        <thead>
          <tr>
            <th>Field</th>
            <th>Type</th>
            <th>Description</th>
          </tr>
        </thead>
        <tbody>
          {names.map((field) => (
            <tr key={field}>
              <td className="align-top whitespace-nowrap">
                <code>{field}</code>
                {required.has(field) ? (
                  <span className="text-fd-muted-foreground"> required</span>
                ) : null}
              </td>
              <td className="align-top whitespace-nowrap">
                <Type fragment={properties[field]} />
              </td>
              <td className="align-top">
                {properties[field].description}
                <Values fragment={properties[field]} />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </>
  );
}
