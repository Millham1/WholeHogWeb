// Normalize teams
const teams = localStorage.getItem('teams');
if (teams) {
  localStorage.setItem('teamsList', teams);
  localStorage.setItem('wh_Teams', teams);
}

// Normalize judges
const judges = localStorage.getItem('judges');
if (judges) {
  localStorage.setItem('judgesList', judges);
  localStorage.setItem('wh_Judges', judges);
}

// Normalize divisions
const divisions = localStorage.getItem('landingTeamDivisions');
if (divisions) {
  localStorage.setItem('wh_Divisions', divisions);
}

// Normalize scores
const onsiteScores = localStorage.getItem('onsiteScores');
if (onsiteScores) {
  localStorage.setItem('wh_OnsiteScores', onsiteScores);
}

const blindScores = localStorage.getItem('blindTasteEntries');
if (blindScores) {
  localStorage.setItem('wh_BlindScores', blindScores);
}

const sauceScores = localStorage.getItem('sauceScores');
if (sauceScores) {
  localStorage.setItem('wh_SauceScores', sauceScores);
}