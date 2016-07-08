' ********** Copyright 2016 Roku Corp.  All Rights Reserved. **********

' A context node has a parameters and response field
' - parameters corresponds to everything related to an HTTP request
' - response corresponds to everything related to an HTTP response
' Component Variables:
'   m.port: the UriFetcher message port
'   m.jobsById: an AA containing a history of HTTP requests/responses

' init(): UriFetcher constructor
' Description: sets the execution function for the UriFetcher
' 						 and tells the UriFetcher to run
sub init()
  ? "[init] - UriHandler.brs"
  ' create the message port
	m.port = createObject("roMessagePort")
	m.top.observeField("request", m.port)
	m.top.functionName = "go"
	m.top.control = "RUN"
end sub

' go(): The "Task" function.
'   Has an event loop which calls the appropriate functions for
'   handling requests made by the HeroScreen and responses when requests are finished
' variables:
'   m.jobsById: AA storing HTTP transactions where:
'			key: id of HTTP request
'  		val: an AA containing:
'       - key: context
'         val: a node containing request info
'       - key: xfer
'         val: the roUrlTransfer object
sub go()
  print "[go] - UriHandler.brs"
  m.jobsById = {}
	' UriFetcher event loop
	while true
		msg = wait(0, m.port)
		mt = type(msg)
		print "UriFetcher: received event type '"; mt; "'"
    ' If a request was made
		if mt = "roSGNodeEvent"
      print "received a request"
			if msg.getField()="request"
				if addRequest(msg.getData()) <> true then print "Invalid request"
			else
				print "UriFetcher: unrecognized field '"; msg.getField(); "'"
			end if
    ' If a response was received
    else if mt="roUrlEvent"
      print "received a response"
			processResponse(msg)
    ' Handle unexpected cases
		else
			print "UriFetcher: unrecognized event type '"; mt; "'"
		end if
	end while
end sub

' addRequest():
'   Makes the HTTP request
' parameters:
'		request: a node containing the request params/context.
' variables:
'   m.jobsById: used to store a history of HTTP requests
' return value:
'   True if request succeeds
' 	False if invalid request
function addRequest(request as Object) as Boolean
  print "[addRequest] - UriHandler.brs"
	' If valid request
  if type(request) = "roAssociativeArray"
    context = request.context
  	if type(context) = "roSGNode"
      parameters = context.parameters
      if type(parameters)="roAssociativeArray"
      	uri = parameters.uri
        if type(uri) = "roString"
          urlXfer = createObject("roUrlTransfer")
          urlXfer.setUrl(uri)
          urlXfer.setPort(m.port)
          ' should transfer more stuff from parameters to urlXfer
          idKey = stri(urlXfer.getIdentity()).trim()
          ' AsyncGetToString returns false if the request couldn't be issued
          ok = urlXfer.AsyncGetToString()
          if ok then m.jobsById[idKey] = {
            context: request,
            xfer: urlXfer
          }
  		    print "UriFetcher: initiating transfer '"; idkey; "' for URI '"; uri; "'"; " succeeded: "; ok
        else
          print "UriFetcher: invalid uri: "; uri
          m.top.content = invalid
  			end if
      end if
  	else
  		return false
  	end if
  end if
  return true
end function

' processResponse():
'   Processes the HTTP response.
'   Sets the node's response field with the response info.
' parameters:
' 	msg: a roUrlEvent (https://sdkdocs.roku.com/display/sdkdoc/roUrlEvent)
sub processResponse(msg as Object)
  print "[processResponse] - UriHandler.brs"
	idKey = stri(msg.GetSourceIdentity()).trim()
	job = m.jobsById[idKey]
	if job <> invalid
    context = job.context
    parameters = context.context.parameters
    uri = parameters.uri
		print "UriFetcher: response for transfer '"; idkey; "' for URI '"; uri; "'"
		result = {
      code:    msg.GetResponseCode(),
      headers: msg.GetResponseHeaders(),
      content: msg.GetString()
    }
		' could handle various error codes, retry, etc.
		m.jobsById.delete(idKey)
    job.context.context.response = result
    print msg.GetResponseCode()
    if msg.GetResponseCode() = 200
      parseResponse(result.content)
    else
      m.top.content = invalid
    end if
	else
		print "UriFetcher: event for unknown job "; idkey
	end if
end sub

sub parseResponse(str As String)

  if str = invalid return
  xml = CreateObject("roXMLElement")
  ' Return invalid if string can't be parsed
  if not xml.Parse(str) return

  If xml <> invalid then
    xml = xml.GetChildElements()
    responseArray = xml.GetChildElements()
  End If

  result = []

  for each xmlItem in responseArray
    if xmlItem.getName() = "item"
      itemAA = xmlItem.GetChildElements()
      if itemAA <> invalid
        item = {}
        for each xmlItem in itemAA
          item[xmlItem.getName()] = xmlItem.getText()
          if xmlItem.getName() = "media:content"
            item.stream = {url : xmlItem.url}
            item.url = xmlItem.getAttributes().url
            item.streamFormat = "mp4"

            mediaContent = xmlItem.GetChildElements()
            for each mediaContentItem in mediaContent
              if mediaContentItem.getName() = "media:thumbnail"
                item.HDPosterUrl = mediaContentItem.getattributes().url
                item.hdBackgroundImageUrl = mediaContentItem.getattributes().url
                item.uri = mediaContentItem.getAttributes().url
              end if
            end for
          end if
        end for
        result.push(item)
      end if
    end if
  end for

  list = [
    {
        Title:"Big Hits"
        ContentList : SelectTo(result, 25)
    }
    {
        Title:"Action"
        ContentList : SelectTo(result, 9)
    }
    {
        Title:"Drama"
        ContentList : SelectTo(result, 25)
    }
    {
        Title:"Explosions"
        ContentList : SelectTo(result, 9)
    }
    {
        Title:"Everybody loves Chris"
        ContentList : SelectTo(result, 25)
    }
  ]

  m.top.content = CreateContent(list)

end sub

Function CreateContent(list As Object)
  print "[CreateContent] - UriHandler.brs"
  RowItems = createObject("RoSGNode","ContentNode")

  'Creates the 6 rows of content above the grid content
  for each rowAA in list
    row = createObject("RoSGNode","ContentNode")
    row.Title = rowAA.Title

    for each itemAA in rowAA.ContentList
      item = createObject("RoSGNode","ContentNode")
      item.SetFields(itemAA)
      row.appendChild(item)
    end for
    RowItems.appendChild(row)
  end for

  'Create the grid content
  for i = 0 to list[0].ContentList.count() step 4
    row = createObject("RoSGNode","ContentNode")
    if i = 0
      row.Title="THE GRID"
    end if
    for j = i to i+3
      if list[0].ContentList[j] <> invalid
        item = createObject("RoSGNode","ContentNode")
        item.SetFields(list[0].ContentList[j])
        row.appendChild(item)
      end if
    end for
    RowItems.appendChild(row)
  end for

  return RowItems
End Function

function SelectTo(array as Object, num = 25 as Integer) as Object
 result = []
 for each item in array
   result.push(item)
   if result.Count() >= num then
     exit for
   end if
 end for
return result
end Function
