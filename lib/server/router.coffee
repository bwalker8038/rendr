# Functions for getting Controllers and Actions.
routes = require('../app/routes')
dataAdapter = require('./data_adapter')
mw = require('./middleware')
sessionsController = require('./sessions_controller')
_ = require('underscore')

# given a name, eg "listings#show"
# return function that matches that controller's action (eg the show method of the listings controller)
getAction = (config) ->
  controller = getController(config.controller);
  controller[config.action]

getController = (controllerName) ->
  require("../app/controllers/#{controllerName}_controller")

getHandler = (action) ->
  (req, res, next) ->
    context =
      app: req.appContext
      redirectTo: (url) -> res.redirect(url)

    params = req.query || {}
    req.route.keys.forEach (routeKey) ->
      params[routeKey.name] = req.route.params[routeKey.name]

    action.call context, params, (err, template, data) ->
      return handleErr(err, req, res) if err
      res.render(template, locals: data, app: req.appContext, req: req)
      mw.logline(null, req, res)

handleErr = (err, req, res) ->
  if err.statusCode && err.statusCode is 401
    res.redirect('/login')
  else
    res.send(err.statusCode)

getAuthenticate = (routeInfo) ->
  (req, res, next) ->
    if routeInfo.authenticated && !req.appContext.SessionManager.loggedIn()
      res.redirect('/login')
    else
      next()

# Attach our routes to our server
exports.buildRoutes = (server) ->
  for own path, routeInfo of routes
    action = getAction(routeInfo)
    handler = getHandler(action)
    authenticate = getAuthenticate(routeInfo)

    server.get("/#{path}", authenticate, handler)

# middleware handler for intercepting api routes
exports.apiProxy = ->
  (req, res, next) ->
    dataAdapter.makeRequest req, (err, response, data) ->
      return next(err) if err
      # Pass through statusCode, but not if it's an i.e. 304.
      if response.statusCode? && _.include(['5', '4'], response.statusCode.toString()[0])
        res.status(response.statusCode)
      res.json(data)
      mw.logline(err, req, res)