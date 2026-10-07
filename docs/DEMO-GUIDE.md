# Client demo guide

Open `/demo`. No account or password is needed. Choose a fictional profile, use **Explore as** to change roles, or use **Start guided walkthrough**. All actions operate on session-local sample records. Each browser tab has an independent walkthrough; this is not a multi-user production workspace.

## Suggested presentation

1. **Marketplace and matching**: follow the Property marketplace link, switch list/map views, filter the sample inventory, open a property, and try the realtor questionnaire. Return to Demo using the header link. Real inventory, agent roster, and listing availability are not represented by these examples.
2. **Prospect → Realtor → Management**: as Prospect, request a demo viewing. Switch to Realtor and confirm it. Return to Prospect, mark the sample document checklist ready, and submit the demo application. Management approves it; Prospect simulates lease signing and move-in. Owner’s demo occupancy changes from 11/12 to 12/12.
3. **Resident → Management → Security → Contractor**: Resident creates a fictional service request. Management assigns Taylor and authorizes access. Security checks Taylor in. Contractor marks the repair complete and submits the sample invoice. Resident confirms the repair; Security checks Taylor out.
4. **Contractor → Finance**: Finance approves and simulates payment of the submitted invoice. The activity history records each handoff, and Owner sees the paid sample vendor cost.
5. **Resident balance**: simulate a resident payment, or switch to Finance and walk through cheque receipt, deposit, and clearance. Only clearance reduces the sample balance. No card information, real payment, tax payment, or real receipt is involved.
6. **Seller**: prepare the sample proposal and approve the simulated launch. This does not publish inventory.
7. **Owner**: explore the sample occupancy, collections, maintenance status, and approximate portfolio map.
8. **What remains**: every profile can open the production backlog in the sidebar.

Use **Reset demo** before repeating the presentation. Simulated actions persist in sessionStorage while navigating the same tab. If browser storage is unavailable, the page explicitly reports that changes last only for the current visit. Closing the tab ends the stored session.

## Important presentation distinction

- Profiles, records, balances, documents, events, and approvals are fictional.
- Demo dashboards illustrate workflows; they are not authenticated roles or verified operational reporting.
- Documents are checklists, not real uploads, verification, or contracts.
- Demo actions send no emails, write no production database records, and move no money.
- Existing marketplace viewing and realtor introduction links create drafts in the viewer’s email client. They send only if the viewer chooses to send the draft.
- Localhost previews run on the presenting computer. A Vercel preview deployment is required for a client to access the demo remotely.
