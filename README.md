hubot-trello-ddx
============

Manage your trello differential diagnosis board from hubot.

This is forked from the [hubot-trello](https://github.com/hubot-scripts/hubot-trello) plugin. It's based on
[this blog post](https://danslimmon.wordpress.com/2015/10/19/troubleshooting-chatops-ddx/).


## Installation

Add **hubot-trello-ddx** to your `package.json` file:

```json
"dependencies": {
  "hubot": ">= 2.5.1",
  "hubot-scripts": ">= 2.4.2",
  "hubot-trello-ddx": "*"
}
```

OR run `npm install --save hubot-trello-ddx`

Add **hubot-trello-ddx** to your `external-scripts.json`:

```json
["hubot-trello-ddx"]
```

Run `npm install`


## Configuration

Setup the following as environment variables before you run hubot.

```
HUBOT_DDX_KEY    - Trello application key
HUBOT_DDX_TOKEN  - Trello API token
HUBOT_DDX_ORGID  - The Trello Team (a.k.a. Organization) ID that should be given access to DDx boards
```

- To get your key, go to: `https://trello.com/1/appKey/generate`
- To get your token, go to: `https://trello.com/1/authorize?key=<<your key>>&name=Hubot+DDx&expiration=never&response_type=token&scope=read,write`
- To get your Organization ID, navigate to the Trello organization's Members page and pick the organization ID out of the URL.

## Sample Interaction

```
Geordi: ddx symptom warp engine going full speed, but ship not moving
Hubot: Created (symp0): warp engine going full speed, but ship not moving
Beverly: ddx falsify hypo1
Hubot: Falsified (hypo1): feedback loop between graviton emitter and graviton roaster
Geordi: ddx finish test1
Hubot: Marked (test1) finished: reboot the quantum phase allometer
```

Here's a [sample](https://trello.com/b/3QprmB6W/ddx-tachyon-flux-fubar) of the sort of Trello board this plugin creates. [My blog post](https://danslimmon.wordpress.com/2015/10/19/troubleshooting-chatops-ddx/) should fill you in if you're still not getting it.
