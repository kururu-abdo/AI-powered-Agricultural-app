enum FeatureModule {
  authentication('Authentication', 'Farmer accounts and farm membership'),
  diseaseDiagnosis('Disease diagnosis', 'On-device image analysis'),
  farmingAdvisor('Farming advisor', 'Offline agricultural guidance'),
  weatherIntelligence('Weather intelligence', 'Forecasts and cached outlooks'),
  cropPlanner('Crop planner', 'Planting, irrigation and harvest schedules'),
  syncManager('Sync manager', 'Pending changes and upload status');

  const FeatureModule(this.title, this.description);
  final String title;
  final String description;
}
