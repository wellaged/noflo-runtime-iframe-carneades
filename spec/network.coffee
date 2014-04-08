describe 'IFRAME network runtime', ->
  iframe = document.getElementById('network').contentWindow
  origin = window.location.origin
  send = (protocol, command, payload) ->
    iframe.postMessage
      protocol: protocol
      command: command
      payload: payload
    , '*'
  receive = (protocol, expects, done) ->
    listener = (message) ->
      chai.expect(message).to.be.an 'object'
      return if message.data.protocol isnt protocol
      expected = expects.shift()
      chai.expect(message.data).to.eql expected
      if expects.length is 0
        window.removeEventListener 'message', listener, false
        done()
    window.addEventListener 'message', listener, false
  describe 'Runtime Protocol', ->
    describe 'requesting runtime metadata', ->
      it 'should provide it back', (done) ->
        listener = (message) ->
          window.removeEventListener 'message', listener, false
          msg = message.data
          chai.expect(msg.protocol).to.equal 'runtime'
          chai.expect(msg.command).to.equal 'runtime'
          chai.expect(msg.payload).to.be.an 'object'
          chai.expect(msg.payload.type).to.equal 'noflo-browser'
          chai.expect(msg.payload.capabilities).to.be.an 'array'
          done()
        window.addEventListener 'message', listener, false
        send 'runtime', 'getruntime', ''

  describe 'Graph Protocol', ->
    describe 'receiving a graph and nodes', ->
      it 'should provide the nodes back', (done) ->
        expects = [
            protocol: 'graph'
            command: 'addnode'
            payload:
              id: 'Foo'
              component: 'core/Repeat'
              metadata:
                hello: 'World'
              graph: 'foo'
          ,
            protocol: 'graph'
            command: 'addnode'
            payload:
              id: 'Bar'
              component: 'core/Drop'
              metadata: {}
              graph: 'foo'
        ]
        receive 'graph', expects, done
        send 'graph', 'clear',
          baseDir: '/noflo-runtime-iframe'
          id: 'foo'
          main: true
        send 'graph', 'addnode', expects[0].payload
        send 'graph', 'addnode', expects[1].payload
    describe 'receiving an edge', ->
      it 'should provide the edge back', (done) ->
        expects = [
          protocol: 'graph'
          command: 'addedge'
          payload:
            src:
              node: 'Foo'
              port: 'out'
            tgt:
              node: 'Bar'
              port: 'in'
            metadata:
              route: 5
            graph: 'foo'
        ]
        receive 'graph', expects, done
        send 'graph', 'addedge', expects[0].payload
    describe 'receiving an IIP', ->
      it 'should provide the IIP back', (done) ->
        expects = [
          protocol: 'graph'
          command: 'addinitial'
          payload:
            src:
              data: 'Hello, world!'
            tgt:
              node: 'Foo'
              port: 'in'
            metadata: {}
            graph: 'foo'
        ]
        receive 'graph', expects, done
        send 'graph', 'addinitial', expects[0].payload
    describe 'removing an IIP', ->
      it 'should provide the IIP back', (done) ->
        expects = [
          protocol: 'graph'
          command: 'removeinitial'
          payload:
            src:
              data: 'Hello, world!'
            tgt:
              node: 'Foo'
              port: 'in'
            metadata: {}
            graph: 'foo'
        ]
        receive 'graph', expects, done
        send 'graph', 'removeinitial',
          tgt:
            node: 'Foo'
            port: 'in'
          graph: 'foo'
    describe 'removing a node', ->
      it 'should remove the node and its associated edges', (done) ->
        expects = [
          protocol: 'graph'
          command: 'removeedge'
          payload:
            src:
              node: 'Foo'
              port: 'out'
            tgt:
              node: 'Bar'
              port: 'in'
            metadata:
              route: 5
            graph: 'foo'
        ,
          protocol: 'graph'
          command: 'removenode'
          payload:
            id: 'Bar'
            component: 'core/Drop'
            metadata: {}
            graph: 'foo'
        ]
        receive 'graph', expects, done
        send 'graph', 'removenode',
          id: 'Bar'
          graph: 'foo'
    describe 'renaming a node', ->
      it 'should send the renamenode event', (done) ->
        expects = [
          protocol: 'graph'
          command: 'renamenode'
          payload:
            from: 'Foo'
            to: 'Baz'
            graph: 'foo'
        ]
        receive 'graph', expects, done
        send 'graph', 'renamenode',
          from: 'Foo'
          to: 'Baz'
          graph: 'foo'

  describe 'Network protocol', ->
    # Set up a clean graph
    beforeEach (done) ->
      waitFor = 4
      listener = (message) ->
        waitFor--
        return if waitFor
        window.removeEventListener 'message', listener, false
        done()
      window.addEventListener 'message', listener, false
      send 'graph', 'clear',
        baseDir: '/noflo-runtime-iframe'
        id: 'bar'
        main: true
      send 'graph', 'addnode',
        id: 'Hello'
        component: 'core/Repeat'
        metadata: {}
        graph: 'bar'
      send 'graph', 'addnode',
        id: 'World'
        component: 'core/Drop'
        metadata: {}
        graph: 'bar'
      send 'graph', 'addedge',
        src:
          node: 'Hello'
          port: 'out'
        tgt:
          node: 'World'
          port: 'in'
        graph: 'bar'
      send 'graph', 'addinitial',
        src:
          data: 'Hello, world!'
        tgt:
          node: 'Hello'
          port: 'in'
        graph: 'bar'
    describe 'on starting the network', ->
      it 'should get started and stopped', (done) ->
        @timeout 15000
        started = false
        listener = (message) ->
          chai.expect(message).to.be.an 'object'
          chai.expect(message.data.protocol).to.equal 'network'
          if message.data.command is 'started'
            chai.expect(message.data.payload).to.be.an 'object'
            chai.expect(message.data.payload.graph).to.equal 'bar'
            chai.expect(message.data.payload.time).to.be.a 'date'
            started = true
          if message.data.command is 'stopped'
            chai.expect(started).to.equal true
            window.removeEventListener 'message', listener, false
            done()
        window.addEventListener 'message', listener, false
        send 'network', 'start',
          graph: 'bar'

  describe 'Component protocol', ->
    describe 'on requesting a component list', ->
      it 'should receive some known components', (done) ->
        listener = (message) ->
          chai.expect(message).to.be.an 'object'
          chai.expect(message.data.protocol).to.equal 'component'
          chai.expect(message.data.payload).to.be.an 'object'
          if message.data.payload.name is 'core/Output'
            chai.expect(message.data.payload.icon).to.equal 'bug'
            chai.expect(message.data.payload.inPorts).to.eql [
              id: 'in'
              type: 'all'
              required: true
              addressable: true
              description: ''
            ,
              id: 'options'
              type: 'object'
              required: true
              addressable: false
              description: ''
            ]
            chai.expect(message.data.payload.outPorts).to.eql [
              id: 'out'
              type: 'all'
              required: true
              addressable: false
              description: ''
            ]
            window.removeEventListener 'message', listener, false
            done()
        window.addEventListener 'message', listener, false
        send 'component', 'list', '/noflo-runtime-iframe'
