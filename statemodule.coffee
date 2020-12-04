statemodule = {name: "statemodule"}
############################################################
#region printLogFunctions
log = (arg) ->
    if allModules.debugmodule.modulesToDebug["statemodule"]?  then console.log "[statemodule]: " + arg
    return
ostr = (obj) -> JSON.stringify(obj, null, 4)
olog = (obj) -> log "\n" + ostr(obj)
print = (arg) -> console.log(arg)
#endregion

############################################################
defaultState = require("./defaultstate")

############################################################
#region internalProperties
state = null
allStates = {}

listeners = {}
changeDetectors = {}

#endregion


############################################################
#region internalFunctions
loadRegularState = ->
    state = localStorage.getItem("state")
    if state? then state = JSON.parse(state)
    else state = defaultState

    for key,content of state #when key != "_dedicatedStates"
        if !content.content?
            state[key] = {content}
        allStates[key] = state[key]
    return

############################################################
#region stateChangeStuff
hasChanged = (oldContent, newContent) -> oldContent != newContent

changeDetected = (key, content) ->
    detector = changeDetectors[key] || hasChanged
    return detector(allStates[key].content, content)

#endregion

loadDedicated = (key) ->
    isDedicated = true
    contentString = localStorage.getItem(key)
    content = JSON.parse(contentString)
    allStates[key] = {content, isDedicated}
    return content

saveDedicatedState = (key) ->

saveRegularState = ->
    log "saveRegularState"
    stateString = JSON.stringify(state)
    localStorage.setItem("state", stateString)
    return


saveAllStates = ->
    for key,content of allStates when content.isDedicated
        saveDedicatedState(key, content.content)
    saveRegularState()
    return

callOnChangeListeners = (key) ->
    log "callOnChangeListeners"
    return if !listeners[key]?
    promises = (fun() for fun in listeners[key])
    await Promise.all(promises)
    return

#endregion

############################################################
#region exposedFunctions
statemodule.getState = -> allStates

############################################################
statemodule.load = (key) ->
    if allStates[key]? and allStates[key].isVolatile
        return allStates[key].content
    if allStates[key]? and !allStates[key].isDedicated
        loadRegularState()
        return allStates[key].content
    return loadDedicated(key)

statemodule.get = (key) -> allStates[key].content

############################################################
statemodule.removeOnChangeListener = (key, fun) ->
    log "statemodule.removeOnChangeListener"
    candidates = listeners[key]
    if candidates?
        for candidate,i in candidates when candidates == fun
            log "candidate found at: " + i
            candidates[i] = candidates[candidates.length - 1]
            candidates.pop()
            return
        log "No candidate found for given function!"
    return

statemodule.addOnChangeListener = (key, fun) ->
    log "statemodule.addOnChangeListener"
    if !listeners[key]? then listeners[key] = []
    listeners[key].push(fun)
    return

statemodule.callOutChange = (key) ->
    log "statemodule.callOutChange"
    try await callOnChangeListeners(key)
    catch err then log err
    return

############################################################
#region stateSetterFunctions
statemodule.saveAll = saveAllStates

############################################################
statemodule.save = (key, content, isDedicated) ->
    log "statemodule.save"
    ##TODO implement
    isVolatile = (allStates[key]? and allStates[key].isVolatile)
    return unless changeDetected(key, content) and !isVolatile

    if typeof isDedicated != "boolean"
        # default is stay with
        isDedicated = (allStates[key]? and allStates[key].isDedicated)
    else if isDedicated != (allStates[key]? and allStates[key].isDedicated)



    if allStates[key]?
        allStates[key].content = content
        allStates[key].isDedicated = isDedicated
    else
        allStates[key] = {content, isDedicated}

    if isDedicated then saveDedicatedState(key)
    else saveRegularState()

    await statemodule.callOutChange(key)
    return

statemodule.saveSilently = (key, content) ->
    log "statemodule.saveSilently"
    return unless changeDetected(key, content)
    state[key].content = content
    saveState(key)
    return

statemodule.set = (key, content) ->
    log "statemodule.set"
    isVolatile = true

    try allStates[key].content = content
    catch err then allStates[key] = {content,isVolatile}
    
    await statemodule.callOutChange(key)
    return

statemodule.setSilently = (key, content) ->
    log "statemodule.setSilently"
    isVolatile = true
    try allStates[key].content = content
    catch err then allStates[key] = {content,isVolatile}
    return

#endregion


#endregion

############################################################
loadRegularState()

module.exports = statemodule