# Dandelion Lite: decentralized Cardano infrastructure for real services

## What Dandelion Lite is

Dandelion Lite is a self-hostable Cardano infrastructure distribution for deploying a Cardano node plus a complete set of useful backend APIs. Its public repository is here: [Dandelion Lite GitHub repo](https://github.com/GameChangerFinance/dandelion-lite).

A Dandelion Lite node can expose services such as Cardano Node, Ogmios, Cardano DB Sync, Koios-style REST APIs, Blockfrost-compatible APIs, Cardano GraphQL MKII, Cardano Token Registry, Submit API, PostGREST, manifests, snapshots and other operational tooling.

The goal is not only to make Cardano APIs easier to deploy. The larger goal is to help decentralize the backend service layer that real Cardano applications depend on.

## Why it exists

Cardano can be decentralized at consensus level while still having dApps, wallets and users depend on a small number of centralized backend providers, DNS endpoints, indexers or load balancers. That creates practical centralization: if a backend fails, rate-limits, censors, lags or disappears, the user experience breaks even if the blockchain itself is healthy.

Dandelion Lite exists to reduce that dependency. It helps more independent operators deploy the same compatible Cardano service stack and participate as Dandelion Node Operators, or DNOs. The more people run the same useful backend services, the more resilient the ecosystem becomes.

## GameChanger Wallet as reference client

GameChanger Wallet is a reference client implementation for this model. It can use Dandelion Lite nodes as decentralized backend peers, with client-side load balancing and on-chain peer discovery.

That matters because decentralization should not stop at “many servers behind one convenient DNS name.” A fully decentralizable Cardano service should let the client discover multiple independent providers, choose among them, fail over when needed, and avoid depending on a single DNS endpoint or centralized backend load balancer.

GameChanger Wallet is one example, but the model is general. Any Cardano wallet, dApp, explorer, education platform, analytics service or protocol can join the Dandelion Network, consume compatible APIs, and contribute rewards to the DNOs serving its users.

## On-chain, self-sovereign registration

Dandelion Lite nodes can publish machine-readable API manifests and node metadata so clients know what services are available.

This design can be combined with self-sovereign on-chain registrations: a node operator writes and updates their own node group definition on Cardano using their own private keys. A reference example is available here: [Write registration to join Dandelion Network with GCFS](https://github.com/GameChangerFinance/gamechanger.wallet/blob/main/examples/Write%20registration%20to%20join%20Dandelion%20Network%20%28GCFS%29.md).

This allows wallets and dApps to discover Dandelion Lite nodes from on-chain data instead of relying on a centralized registry. Operators can list their own node+APIs, update their metadata, and become discoverable by compatible clients.

## Why universal APIs matter

Another reason Dandelion and general-purpose APIs matter is reuse. Cardano projects often create custom chain indexers for their own narrow needs. That may work for one project, but it fragments infrastructure: nobody else wants to deploy, maintain or audit a highly specific backend that only serves one application.

Dandelion Lite promotes the opposite strategy: deploy universal backend systems that many projects can share. APIs such as Blockfrost-compatible endpoints and especially Cardano GraphQL MKII make it possible for more builders to use the same backend projects, improve them together, and make them worth operating at scale.

The more projects use common backend standards, the more node operators have a reason to deploy them. The more operators deploy them, the more decentralized and reliable the ecosystem becomes.

## Community rewards and sustainability

Dandelion Lite also supports a sustainability model. DNOs are not just donating infrastructure; they can serve real users and potentially be rewarded by the projects and communities that benefit from their nodes.

GameChanger’s community reward program points in this direction: users, integrators and backend operators can help decentralize GameChanger Wallet and other Cardano services while participating in reward flows. Other Cardano projects can adopt the same idea by routing traffic through client-side peer discovery and contributing incentives to the operators who keep their services online.

## Concept glossary

**Dandelion Lite**: A self-hostable Cardano node and API stack for deploying compatible backend services.

**DNO**: Dandelion Node Operator. A person or organization running a Dandelion Lite or compatible node.

**API manifest**: Machine-readable metadata describing which APIs a node exposes and how clients can use them.

**GCFS**: GameChanger File System, used here as a way to publish node registration data on-chain.

**On-chain peer discovery**: A method where clients discover service providers by reading registrations from Cardano instead of trusting a centralized list.

**Client-side load balancing**: The wallet or dApp chooses between multiple backend peers directly, avoiding dependence on a single DNS or centralized load balancer.

**Universal backend API**: A reusable API system, such as Blockfrost-compatible services or Cardano GraphQL MKII, designed to serve many projects instead of one custom app.

## Key links

* Dandelion Lite repo: https://github.com/GameChangerFinance/dandelion-lite
* On-chain Dandelion registration example: https://github.com/GameChangerFinance/gamechanger.wallet/blob/main/examples/Write%20registration%20to%20join%20Dandelion%20Network%20%28GCFS%29.md
* GameChanger Finance: https://gamechanger.finance/
* Gimbalabs Dandelion page: https://www.gimbalabs.com/dandelion
