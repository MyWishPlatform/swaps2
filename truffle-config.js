module.exports = {
  networks: {
  compilers: {
    solc: {
      version: "0.5.7",
      settings: {
       optimizer: {
         enabled: true,
         runs: 200
       },
      }
    }
  }
}
