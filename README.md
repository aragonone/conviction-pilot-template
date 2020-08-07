# Conviction Pilot Template

Aragon DAO Template for Conviction Pilot program.

Takes a reference minime token, admin address, and conviction parameters as input, and deploys an organization using a clone of the reference token for use with conviction voting and uses the reference token itself for funding proposals. In practice this will be used with the ANT token, so voting influence will be determined by ANT balance at some blockheight for the duration of the pilot, and ANT will be used as the currency for proposals. The admin address has full control over the deployment and can remove funds, modify balances, or upgrade the conviction voting app. 


## Rinkeby deployment using previously deployed template

To deploy a pilot dao to Rinkeby:

1) Install dependencies:
```
$ npm install
```

2) Compile contracts:
```
$ npx truffle compile
```

3) Configure deployment in: `scripts/new-pilot.js`

4) Deploy a DAO to Rinkeby (requires a Rinkeby account accessible by the truffle script as documented here:
https://hack.aragon.org/docs/cli-intro#set-a-private-key):
```
$ npx truffle exec scripts/new-pilot.js --network rinkeby
```

5) Copy the output DAO address into this URL and open it in a web browser:
```
https://rinkeby.aragon.org/#/<DAO address>
```
