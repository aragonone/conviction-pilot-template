const PilotTemplate = artifacts.require("PilotTemplate")
const Token = artifacts.require("Token")

const DAO_ID = "pilot" + Math.random() // Note this must be unique for each deployment, change it for subsequent deployments
const NETWORK_ARG = "--network"
const DAO_ID_ARG = "--daoid"



const argValue = (arg, defaultValue) => process.argv.includes(arg) ? process.argv[process.argv.indexOf(arg) + 1] : defaultValue

const network = () => argValue(NETWORK_ARG, "local")
const daoId = () => argValue(DAO_ID_ARG, DAO_ID)

const pilotTemplateAddress = () => {
  if (network() === "rinkeby") {
    const Arapp = require("../arapp")
    return Arapp.environments.rinkeby.address
  } else if (network() === "mainnet") {
    const Arapp = require("../arapp")
    return Arapp.environments.mainnet.address
  } else if (network() === "xdai") {
    const Arapp = require("../arapp")
    return Arapp.environments.xdai.address
  } else {
    const Arapp = require("../arapp_local")
    return Arapp.environments.devnet.address
  }
}

const DAYS = 24 * 60 * 60
const ONE_HUNDRED_PERCENT = 1e18
const ONE_TOKEN = 1e18

// Create dao transaction one config
// const REFERENCE_TOKEN = "0x1ea885084dd4747be71da907bd71fc9484af618d" // Test HNY from rinkeby.aragon.org/#/honey
const REFERENCE_TOKEN = "0x8cf8196c14A654dc8Aceb3cbb3dDdfd16C2b652D" // Test ANT from Court deployment
const SNAPSHOT_BLOCK = 0 // Use 0 if you want to snapshot at the current blockheight.
const ADMIN = "0x625236038836CecC532664915BD0399647E7826b"

const DECAY= 9999799 // 48 hours halftime
const MAX_RATIO = 2000000 // 20 percent
const MIN_THRESHOLD = 0.01 // 1 percent
const MIN_EFFECTIVE_SUPPLY = 0.05 * ONE_HUNDRED_PERCENT // 5% minimum effective supply
const WEIGHT = MAX_RATIO ** 2 * MIN_THRESHOLD / 10000000 // determine weight based on MAX_RATIO and MIN_THRESHOLD
const CONVICTION_SETTINGS = [DECAY, MAX_RATIO, WEIGHT, MIN_EFFECTIVE_SUPPLY]

module.exports = async (callback) => {
  try {
    const pilotTemplate = await PilotTemplate.at(pilotTemplateAddress())

    const createDaoTxOneReceipt = await pilotTemplate.createDaoTxOne(
      REFERENCE_TOKEN,
      SNAPSHOT_BLOCK,
      ADMIN,
      CONVICTION_SETTINGS
    );
    console.log(`Tx One Complete. DAO address: ${createDaoTxOneReceipt.logs.find(x => x.event === "DeployDao").args.dao} Gas used: ${createDaoTxOneReceipt.receipt.gasUsed} `)


  } catch (error) {
    console.log(error)
  }
  callback()
}
