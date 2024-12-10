// --------------------------------------------------------------------------------------------------------------
// The most minimal parameters you need - everything else is defaulted
// --------------------------------------------------------------------------------------------------------------
using 'main-complete.bicep'

param applicationName = '#{appNameLower}#'          // from the variable group *(supply either name or prefix...)
param location = '#{location}#'                     // from the variable group
param environmentName = '#{environmentNameLower}#'  // from the pipeline
param append_Resource_Token = false
