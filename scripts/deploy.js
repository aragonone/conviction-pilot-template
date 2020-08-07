const deployTemplate = require('@aragon/templates-shared/scripts/deploy-template')

const TEMPLATE_NAME = 'pilot-template'
const CONTRACT_NAME = 'PilotTemplate'

module.exports = (callback) => {
  deployTemplate(web3, artifacts, TEMPLATE_NAME, CONTRACT_NAME)
    .then(template => {
      console.log("Pilot Template address: ", template.address)
    })
    .catch(error => console.log(error))
    .finally(callback)
}
