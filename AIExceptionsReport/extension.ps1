function Get-XmlNamespaceManager([xml]$XmlDocument, [string]$NamespaceURI = "") {
    # If a Namespace URI was not given, use the Xml document's default namespace.
	if ([string]::IsNullOrEmpty($NamespaceURI)) { $NamespaceURI = $XmlDocument.DocumentElement.NamespaceURI }	
	
	# In order for SelectSingleNode() to actually work, we need to use the fully qualified node path along with an Xml Namespace Manager, so set them up.
	[System.Xml.XmlNamespaceManager]$xmlNsManager = New-Object System.Xml.XmlNamespaceManager($XmlDocument.NameTable)
	$xmlNsManager.AddNamespace("ns", $NamespaceURI)
    return ,$xmlNsManager		# Need to put the comma before the variable name so that PowerShell doesn't convert it into an Object[].
}

function Get-FullyQualifiedXmlNodePath([string]$NodePath, [string]$NodeSeparatorCharacter = '.')
{
    return "/ns:$($NodePath.Replace($($NodeSeparatorCharacter), '/ns:'))"
}

function Get-XmlNode([xml]$XmlDocument, [string]$NodePath, [string]$NamespaceURI = "", [string]$NodeSeparatorCharacter = '.') {
	$xmlNsManager = Get-XmlNamespaceManager -XmlDocument $XmlDocument -NamespaceURI $NamespaceURI
	[string]$fullyQualifiedNodePath = Get-FullyQualifiedXmlNodePath -NodePath $NodePath -NodeSeparatorCharacter $NodeSeparatorCharacter
	
	# Try and get the node, then return it. Returns $null if the node was not found.
	$node = $XmlDocument.SelectSingleNode($fullyQualifiedNodePath, $xmlNsManager)
	return $node
}

function New-XmlNode([ xml ]$XmlDocument, [System.Xml.XmlElement] $Node, [string]$NodePath, [switch]$DuplicatesAllowed, [string]$NodeSeparatorCharacter = '.') {
    $PathArray = $NodePath.Split($NodeSeparatorCharacter)
    $CurentPath = ""
    $parentNode = $Node
    For ($i=0; $i -lt $PathArray.Length ; $i++) {
        $CurentPath = $PathArray[$i]
        $ChildNode = $parentNode.GetElementsByTagName($CurentPath)
        if ( ($ChildNode.Count -eq 0) -or (($i -eq $PathArray.Length-1) -and ($DuplicatesAllowed) )) {
            $ChildNode = $XmlDocument.CreateNode("element",$CurentPath,$XmlDocument.DocumentElement.NamespaceURI)
            $parentNode.AppendChild($ChildNode) > $null
        }
        $parentNode = $ChildNode
    }
    return $parentNode
}

function Add-XmlAttribute([ xml ]$XmlDocument, [System.Xml.XmlElement]$Node, [string]$AttributeName, [string]$AttributeValue, [string]$NamespaceURI = "") {
		$attribute = $XmlDocument.CreateNode([System.Xml.XmlNodeType]::Attribute, $AttributeName, $NamespaceURI)
		$attribute.Value = $AttributeValue
        $node.Attributes.SetNamedItem($attribute) > $null
}

function Add-XmlCDataSection([ xml ]$XmlDocument, [System.Xml.XmlElement]$Node, [string]$CDataSectionValue, [string]$NamespaceURI = "") {
		$CDataSection = $XmlDocument.CreateNode([System.Xml.XmlNodeType]::CDATA, $CDataSectionName, $NamespaceURI)
		$CDataSection.Value = $CDataSectionValue
        $node.AppendChild($CDataSection) | Out-Null
}

function Get-ApplicationInsightsHeader ([string]$ApplicationInsightsAPIAccessKey) {
    $headers = @{    
        "X-Api-Key"    = $ApplicationInsightsAPIAccessKey
        "Content-Type" = "application/json"
    }
    return $headers
}

function Get-ApplicationInsightsQuery ( [string]$Query, [string]$ApplicationInsightsAPIAccessKey, [string]$ApplicationInsightsId, [string]$Timespan="" ) {
    $URI = "https://api.applicationinsights.io/v1/apps/$ApplicationInsightsId/query?query=$Query"
    if( ![string]::IsNullOrEmpty($Timespan)) {
        $URI += "&timespan=$Timespan"
    }
    $URI = [uri]::EscapeUriString($URI)
    $headers = Get-ApplicationInsightsHeader -ApplicationInsightsAPIAccessKey $ApplicationInsightsAPIAccessKey
    $Response = Invoke-WebRequest -Method Get -Uri $URI -Headers $headers
    return (ConvertFrom-Json $Response.Content).tables
}
