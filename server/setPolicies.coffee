###*
 * Function that adds and orders any defined policies as specified in config/policies.coffee
 * @param data Contains information about controllers and policies
 * @param data.controllers object containing defined controller objects
 * @param data.policies object containing defined policy functions
 * @param data.config contains policy configuration for controller actions
 * @returns {Object} Transformed controllers object with controller methods in array format
###
module.exports = (data) ->
	_                      = require('lodash')
	typeCheck              = require('type-check').typeCheck
	controllers            = data.controllers
	policies               = data.policies
	config                 = data.config
	policiesAndControllers = _.cloneDeep(controllers)
	globalPolicyFns        = []


	# True Policy
	# Policy when * is true in config.policies
	truePolicy = (req,res,next) ->
		next()

	# False Policy
	# Policy when * is false in config.policies
	falsePolicy = (req,res) ->
		res.notFound()

	# Adds functions to the front of the controller action
	addPolicies = (controller, action, fns) ->
		if !typeCheck('[Function]', fns)
			throw Error('addPolicies: expected array of functions.')
		if !controller
			throw Error('addPolicies: Controller is undefined')
		if !controller[action]
			throw Error("addPolicies: Controller action #{action} is undefined")
		if !typeCheck('Array', controller[action])
			controller[action] = [controller[action]]
		controller[action] = fns.concat(controller[action])

	# Adds functions to the front of all controller actions that don't currently have a func
	addDefaultPolicies = (controller, fns) ->
		if !typeCheck('[Function]', fns)
			throw Error('addDefaultPolicies: expected array of functions.')
		if !controller
			throw Error('addDefaultPolicies: Controller is undefined')
		for action,value of controller
			if (value.length == 1)
				addPolicies(controller,action,fns)

	# Util to reference policy functions in array
	makePolicyArray = (policyNamesToApply) ->
		policyFns = []
		if typeCheck('String', policyNamesToApply)
			policyNamesToApply = [policyNamesToApply]
		for policyName in policyNamesToApply
			if !policies[policyName]
				throw Error("config.policies: policy #{policyName} does not exist")
			if !typeCheck('Function', policies[policyName])
				throw Error("policy #{policyName} should export a function, but instead got #{typeof policies[policyName]}")
			policyFns.push policies[policyName]
		return policyFns

	# First place all controller actions into an array
	# And check controllers are correctly defined
	do ->
		for controllerName, controller of policiesAndControllers
			if !typeCheck('Object', controller)
				throw Error "#{controllerName} should export an object"
			for actionName, action of controller
				if !typeCheck('Function', action)
					throw Error "#{controllerName}.#{actionName} should be a function"
				policiesAndControllers[controllerName][actionName] = [action]

	# Loop through policy config and apply policies
	if typeCheck('Object', policies)
		for controller,actions of config.policies

			# Set globalPolicyFns
			if controller == '*'
				if actions == true
					globalPolicyFns.push(truePolicy)
				else if actions == false
					globalPolicyFns.push(falsePolicy)
				else
					globalPolicyFns = makePolicyArray(actions)
			else
				# Check if controller exists
				if !policiesAndControllers[controller]
					throw Error("config.policies: Controller #{controller} does not exist")

				# Add policies for specific actions only first
				do ->
					for action, policyNamesToApply of actions
						if action != "*"
							# Check if controller action exists
							if !policiesAndControllers[controller][action]
								throw Error("config.policies: Controller action #{controller}.#{action} does not exist")

							policyFns = makePolicyArray(policyNamesToApply)
							addPolicies(policiesAndControllers[controller], action, policyFns)

				# Add policies to * actions if specified. This must be done last
				do ->
					for action, policyNamesToApply of actions
						if action == "*"
							if policyNamesToApply == true
								policyFns = [truePolicy]
							else if policyNamesToApply == false
								policyFns = [falsePolicy]
							else
								policyFns = makePolicyArray(policyNamesToApply)
							addDefaultPolicies(policiesAndControllers[controller], policyFns)

	# Add global default policies to any other controller actions that do not have a policy
	do ->
		if globalPolicyFns.length > 0
			for controllerName,controller of policiesAndControllers
				addDefaultPolicies(controller, globalPolicyFns)

	return policiesAndControllers
