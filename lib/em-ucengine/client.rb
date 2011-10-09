# -*- coding: utf-8 -*-
require "uri"
require "json"


module UCEngine
  class Client

    # Create a new U.C.Engine client
    #
    # @param [String] Host of the U.C.Engine instance
    # @param [Number] Port of the U.C.Engine instance
    # @param [String] Entry point of the API
    # @param [String] Version of U.C.Engine API
    def initialize(host="localhost", port=5280, api_root="/api", api_version="0.6")
      @host = host
      @port = port
      @root = api_root
      @version = api_version
    end

    # Format url to api
    #
    # @param [String] Path of the method
    def url(path)
      URI.escape("http://#{@host}:#{@port}#{@root}/#{@version}#{path}")
    end

    # Get server time
    def time(&block)
      Session.new(self, nil, nil).time &block
    end

    # Connect to U.C.Engine
    #
    # @param [String] User name
    # @param [String] Password
    # @param [Hash] Metadata of the user
    def connect(user, password, metadata=nil, &block)
      body = { "name" => user, "credential" => password }
      body["metadata"] = metadata if metadata
      req = post(url("/presence"), {}, body)
      answer_connect(req, &block)
    end

    # Create a user
    #
    # @param [Hash] data
    def create_user(data)
      # FIXME: for now users can't be created with metadata.
      answer post("/user", data), &block
    end

    # Session represent the U.C.Engine client with and sid and uid
    # See #connect
    class Session < Struct.new(:uce, :uid, :sid)
      def url(*args)
        uce.url(*args)
      end

      ### Time - http://docs.ucengine.org/api.html#time ###

      # Get server time
      def time(&block)
        answer get(url("/time")), &block
      end

      ### Presence - http://docs.ucengine.org/api.html#authentication ###

      # Get infos on the presence
      #
      # @param [String] Sid
      def presence(sid, &block)
        answer get(url("/presence/#{sid}")), &block
      end

      # Disconnect a user
      #
      # @param [String] Sid
      def disconnect(sid, &block)
        answer delete(url "/presence/#{sid}"), &block
      end

      ### Users - http://docs.ucengine.org/api.html#user ###

      # List users
      def users(&block)
        answer get(url "/user"), &block
      end

      # Get user info
      #
      # @param [String] uid
      def user(uid, &block)
        answer get(url("/user/#{uid}")), &block
      end

      # Create user
      #
      # @param [Hash] data
      def create_user(data, &block)
        answer post(url("/user"), data), &block
      end

      # Update user
      #
      # @param [String] uid
      # @param [Hash] data
      def update_user(uid, data, &block)
        answer put(url("/user/#{uid}"), data), &block
      end

      # Delete a user
      #
      # @param [String] uid
      def delete_user(uid, &block)
        answer delete(url("/user/#{uid}")), &block
      end

      # Check user ACL
      #
      # @param [String] uid
      # @param [String] action
      # @param [String] object
      # @param [Hash] conditions
      # @param [String] meeting name
      def user_can(uid, action, object, conditions={}, location="", &block)
        answer_bool get(url("/user/#{uid}/can/#{action}/#{object}/#{location}"), :conditions => conditions), &block
      end

      ### Meetings - http://docs.ucengine.org/api.html#meeting ###

      # List meetings
      #
      def meetings(&block)
        answer get(url "/meeting/"), &block
      end

      # Get meeting
      #
      # @param [String] meeting
      def meeting(meeting, &block)
        answer get(url "/meeting/#{meeting}"), &block
      end

      # Create a meeting
      #
      # @param [String] meeting name
      # @param [Hash] metadata
      def create_meeting(meeting, body={}, &block)
        body.merge!(:name => meeting)
        answer post(url("/meeting/"), body), &block
      end

      # Update a meeting
      #
      # @param [String] meeting name
      # @param [Hash] metadata
      def update_meeting(meeting, body={}, &block)
        answer put(url "/meeting//#{meeting}", body), &block
      end

      ### Rosters - http://docs.ucengine.org/api.html#join-a-meeting ###

      # List users on the meeting
      #
      # @param [String] meeting
      def roster(meeting, &block)
        answer get(url "/meeting/#{meeting}/roster"), &block
      end

      # Join the meeting
      #
      # @param [String] meeting
      def join_roster(meeting, body={}, &block)
        answer post(url "/meeting/#{meeting}/roster", body), &block
      end

      # Quit the meeting
      #
      # @param [String] meeting
      # @param [String] uid
      def quit_roster(meeting, uid=nil, &block)
        answer delete(url "/meeting/#{meeting}/roster/#{uid || @uid}"), &block
      end

      ### Events - http://docs.ucengine.org/api.html#events ###

      # Get events
      #
      # @param [String] meeting
      # @param [Hash] params
      def events(meeting=nil, params={}, &block)
        answer get(url("/event/#{meeting}"), params), &block
      end

      # Publish event
      #
      # @param [String] type
      # @param [String] meeting
      # @param [Hash] metadata
      def publish(type, meeting=nil, metadata=nil, parent=nil, &block)
        args = { :type => type, :uid => uid, :sid => sid }
        args[:parent] = parent if parent
        args[:metadata] = metadata if metadata
        answer json_post(url("/event/#{meeting}"), args), &block
      end

      # Get event
      #
      # @param [String] id
      def event(id, &block)
        # Fixme: remove meeting fake param on the 0.7 release
        answer get(url("/event/meeting/#{id}"), {}), &block
      end

      # Search
      #
      # @param [Hash] params
      def search(params, &block)
        answer get(url "/search/event/", params, &block)
      end

      ### Files - http://docs.ucengine.org/api.html#upload-a-file ###

      # Delete a file
      #
      # @param [String] meeting
      # @param [String] filename
      def delete_file(meeting, filename, &block)
        answer delete(url("/file/#{meeting}/#{filename}")), &block
      end

      # List files on a meeting room
      #
      # @param [String] meeting
      # @param [Hash] params
      def files(meeting, params={}, &block)
        answer get(url("/file/#{meeting}"), params), &block
      end

      ### Roles - http://docs.ucengine.org/api.html#roles ###

      # Create a role
      #
      # @param [Hash] data
      def create_role(data, &block)
        answer post(url("/role/"), data), &block
      end

      # Delete a role
      #
      # @param [String] name
      def delete_role(name, &block)
        answer delete(url "/role/#{name}"), &block
      end

      # Set a role to a user
      #
      # @param [String] uid
      # @param [Hash] params
      def user_role(uid, params={}, &block)
        answer post(url("/user/#{uid}/roles"), params), &block
      end
    end
  end
end

