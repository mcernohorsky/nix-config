#set document(
  title: "Project Proposal",
  author: "Matt Cernohorsky",
)

#set page(
  paper: "us-letter",
  margin: (
    x: 1in,
    y: 0.85in,
  ),
)

#set text(
  font: "New Computer Modern",
  size: 11pt,
)

#set heading(numbering: "1.")
#set par(justify: true, leading: 0.65em)

#show heading.where(level: 1): it => [
  #v(0.8em)
  #it
  #v(0.3em)
]

= Project Proposal

#grid(
  columns: (1fr, 1fr),
  gutter: 1em,
  [*Prepared by:* Matt Cernohorsky],
  [*Date:* #datetime.today().display("[month repr:long] [day], [year]")],
)

== Summary

Describe the project, the problem it solves, and the outcome this proposal is requesting approval to pursue.

== Goals

- Define the primary result.
- Identify measurable success criteria.
- State what is intentionally out of scope.

== Approach

Explain the implementation strategy, major phases, and important technical or operational decisions.

== Timeline

#table(
  columns: (1fr, 2fr),
  inset: 8pt,
  align: horizon,
  [*Phase*], [*Deliverable*],
  [Discovery], [Requirements, constraints, and open questions],
  [Implementation], [Working draft or prototype],
  [Review], [Feedback, revision, and final delivery],
)

== Risks

- Risk: Describe a material uncertainty.
  Mitigation: Explain how it will be reduced or monitored.

== Budget

Summarize expected cost, time, tooling, or resource needs.

== Next Steps

- Confirm scope.
- Assign owners.
- Set the first milestone.
