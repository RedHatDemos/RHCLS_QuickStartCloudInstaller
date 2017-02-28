#!/bin/bash
# Could be run from the bastion workstation after you install hammer
#sudo yum -y install rubygem-hammer_cli_foreman
mkdir -p /root/.hammer

# Feed hammer the admin password (This helps on the satellite too)
cat > /root/.hammer/cli_config.yml <<HAMMERTIME
:modules:
    - hammer_cli_foreman

:foreman:
    :host: 'https://satellite.example.com'
    :username: 'admin'
    :password: 'changeme'
HAMMERTIME

# Create a snippet for the actual hack code
cat > /root/cpu_map_xml << 'SNIPPET'
echo "Altering cpu map file"

cp /usr/share/libvirt/cpu_map.xml /root/cpu_map.xml.ori

cat > /root/cpu_map.xslt << EOF
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:template match="model[@name = 'Opteron_G2']">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <vendor name='Intel'/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
EOF

xsltproc /root/cpu_map.xslt /root/cpu_map.xml.ori | xmllint --format - > /usr/share/libvirt/cpu_map.xml
echo "cpu map alterations complete"
SNIPPET

hammer template create --name 'cpu_map_xml' --file /root/cpu_map_xml --type snippet

# Dump out the default kickstart template
hammer template dump --name 'Satellite Kickstart Default' > kickstart.erb
# Reference our snippet
awk '/^@Core$/ {print "libvirt-client\nlibxml2";} /^sync$/ {print "<%= snippet '"'cpu_map_xml'"' %>"; } 1' kickstart.erb > kickstart-edited.erb
# Unlock, push change, lock again
hammer template update --name 'Satellite Kickstart Default' --locked false
hammer template update --name 'Satellite Kickstart Default' --file kickstart-edited.erb
hammer template update --name 'Satellite Kickstart Default' --locked true



