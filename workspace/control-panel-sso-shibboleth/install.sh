#!/bin/bash

IDP_DOMAIN=""
SP_DOMAIN=""
ENABLE_SLO=true

if [ "$1" == "" ]; then
  echo "Basic parameters are missing. Use: -? | -h | --help"
  exit 1
fi

while [ "$1" != "" ]; do
        case $1 in

                -id | --idp_domain )
                        if [ "$2" != "" ]; then
                                IDP_DOMAIN=$2
                                shift
                        fi
                ;;

                -sd | --sp_domain )
                        if [ "$2" != "" ]; then
                                SP_DOMAIN=$2
                                shift
                        fi
                ;;

                -nl | --no_slo )
                        ENABLE_SLO=false
                ;;

                -? | -h | --help )
                        echo "  Usage $0 [PARAMETER] [[PARAMETER], ...]"
                        echo "    Parameters:"
                        echo "      -id, --idp_domain        your idp domain name (ex. 'shibbolethoo.tk')"
                        echo "      -sd, --sp_domain         your sp domain name (ex. 'docker4.tk')"
                        echo "      -nl, --no_slo            disable SLO (no setup single logout for IDP)"
                        echo "      -?, -h, --help           this help"
                        echo "  Sample: ./install.sh -id shibbolethoo.tk -sd docker4.tk --no_slo"
                        echo
                        exit 0

                ;;

                * )
                        echo "Unknown parameter $1" 1>&2
                        exit 0
                ;;
        esac
        shift
done

if [ "$IDP_DOMAIN" == "" ]; then
  echo "Empty IDP domain. Use: -? | -h | --help"
  exit 1
fi

if [ "$SP_DOMAIN" == "" ]; then
  echo "Empty SP domain. Use: -? | -h | --help"
  exit 1
fi

# get second domain -> example
D2=$(echo "${IDP_DOMAIN}" | awk -F . '{print$1}') 

# get get first domain -> com
D1=$(echo "${IDP_DOMAIN}" | awk -F . '{print$2}') 

DOWNLOAD_URL="https://codeload.github.com/ONLYOFFICE/dockerized-idp-testbed/zip/feature/php-cas-from-release"

APP_DIR="/app"
BASE_DIR="${APP_DIR}/dockerized-idp-testbed-master"
IDP_DIR="${BASE_DIR}/idp/shibboleth-idp"
IDP_CONF_DIR="${IDP_DIR}/conf"

ZIP_ARCHIVE_FILE="${BASE_DIR}".zip

IDP_ATTR_FILTER_FILE="${IDP_CONF_DIR}"/attribute-filter.xml
IDP_ATTR_RESOLVER_FILE="${IDP_CONF_DIR}"/attribute-resolver.xml
IDP_META_PROVIDERS_FILE="${IDP_CONF_DIR}"/metadata-providers.xml
IDP_PROPERTIES_FILE="${IDP_CONF_DIR}"/idp.properties
IDP_CAS_PROTOCOL_FILE="${IDP_CONF_DIR}"/cas-protocol.xml
IDP_RELYING_PARTY_FILE="${IDP_CONF_DIR}"/relying-party.xml
IDP_META_FILE="${IDP_DIR}"/metadata/idp-metadata.xml

SP_DEV_HTTP_META_FILE="${IDP_DIR}"/metadata/sp-onlyoffice1.xml
SP_DEV_HTTPS_META_FILE="${IDP_DIR}"/metadata/sp-onlyoffice2.xml

LDAP_USERS_FILE="${BASE_DIR}"/ldap/users.ldif

echo "PARAMETERs: "
echo "IDP DOMAIN: ${IDP_DOMAIN} (SLD: ${D2} TLD: ${D1})"
echo "IDP SLO ENABLE: ${ENABLE_SLO}"
echo "SP DOMAIN: ${SP_DOMAIN}"
echo "APP_DIR: ${APP_DIR}"
echo "BASE_DIR: ${BASE_DIR}"
echo "IDP_CONF_DIR: ${IDP_CONF_DIR}"
echo "DOWNLOAD_URL: ${DOWNLOAD_URL}"
echo "ZIP_ARCHIVE_FILE: ${ZIP_ARCHIVE_FILE}"
echo "IDP_ATTR_FILTER_FILE: ${IDP_ATTR_FILTER_FILE}"
echo "IDP_ATTR_RESOLVER_FILE: ${IDP_ATTR_RESOLVER_FILE}"
echo "IDP_META_PROVIDERS_FILE: ${IDP_META_PROVIDERS_FILE}"
echo "IDP_PROPERTIES_FILE: ${IDP_PROPERTIES_FILE}"
echo "IDP_CAS_PROTOCOL_FILE: ${IDP_CAS_PROTOCOL_FILE}"
echo "IDP_RELYING_PARTY_FILE: ${IDP_RELYING_PARTY_FILE}"
echo "IDP_META_FILE: ${IDP_META_FILE}"
echo "SP_DEV_HTTP_META_FILE: ${SP_DEV_HTTP_META_FILE}"
echo "SP_DEV_HTTPS_META_FILE: ${SP_DEV_HTTPS_META_FILE}"
echo "LDAP_USERS_FILE: ${LDAP_USERS_FILE}"
echo ""

# create /app/ directory if needed
mkdir -p "${APP_DIR}"

echo "Downloading dockerized-idp-testbed.zip from UniconLabs"
echo ""
curl "${DOWNLOAD_URL}" > "${ZIP_ARCHIVE_FILE}"
echo ""

if [ ! -f "${ZIP_ARCHIVE_FILE}" ]; then
    echo ""
    echo "Zip archive \"${ZIP_ARCHIVE_FILE}\" not found!"
    exit 1
fi

# stop previous idp and remove it's directory 
if [[ -d "${BASE_DIR}" ]]; then
 echo "Dockerized-idp-testbed already exists, try to recreate"
 docker-compose -f "${BASE_DIR}"/docker-compose.yml down
 rm -drf "${BASE_DIR}"
fi

# unzip dockerized-idp-testbed.zip
echo "Unzip dockerized-idp-testbed.zip"
unzip "${ZIP_ARCHIVE_FILE}" -d "${APP_DIR}"/
mv /app/dockerized-idp-testbed-feature-php-cas-from-release /app/dockerized-idp-testbed-master

# replace hardcoded "idptestbed" domain to input IDP_DOMAIN

grep 'idptestbed.edu' -P -R -I -l "${BASE_DIR}"/ | xargs sed -i 's/idptestbed.edu/'"${IDP_DOMAIN}"'/g' 
grep 'dc=idptestbed' -P -R -I -l "${BASE_DIR}"/ | xargs sed -i 's/dc=idptestbed/dc='"${D2}"',dc='"${D1}"'/g'
grep 'idptestbed' -P -R -I -l "${BASE_DIR}"/ | xargs sed -i 's/idptestbed/'"${IDP_DOMAIN}"'/g'

# append SP_DOMAIN to attribute-filter.xml and setup right attributes

CONTENT='\t<AttributeFilterPolicy id="onlyoffice">\n
         \t<PolicyRequirementRule xsi:type="OR">\n
         \t\t     <Rule xsi:type="Requester" value="http://'"${SP_DOMAIN}"'/sso/metadata" />\n
         \t\t     <Rule xsi:type="Requester" value="https://'"${SP_DOMAIN}"'/sso/metadata" />\n
         \t\t     <Rule xsi:type="Requester" value="http://localhost/sso/metadata" />\n
         \t\t     <Rule xsi:type="Requester" value="https://localhost/sso/metadata" />\n
         \t</PolicyRequirementRule>\n
         \t<AttributeRule attributeID="mail">\n
         \t\t     <PermitValueRule xsi:type="ANY" />\n
         \t</AttributeRule>\n
         \t<AttributeRule attributeID="surname">\n
         \t\t     <PermitValueRule xsi:type="ANY" />\n
         \t</AttributeRule>\n
         \t<AttributeRule attributeID="givenName">\n
         \t\t     <PermitValueRule xsi:type="ANY" />\n
         \t</AttributeRule>\n
         \t<AttributeRule attributeID="mobileNumber">\n
         \t\t     <PermitValueRule xsi:type="ANY" />\n
         \t</AttributeRule>\n
         \t<AttributeRule attributeID="title">\n
         \t\t     <PermitValueRule xsi:type="ANY" />\n
         \t</AttributeRule>\n
         \t<AttributeRule attributeID="locality">\n
         \t\t     <PermitValueRule xsi:type="ANY" />\n
         \t</AttributeRule>\n
         \t</AttributeFilterPolicy>'

C=$(echo $CONTENT | sed 's/\//\\\//g')

sed -i "/<\/AttributeFilterPolicyGroup>/ s/.*/${C}\n&/" "${IDP_ATTR_FILTER_FILE}"

#cat "${IDP_ATTR_FILTER_FILE}"

# setup missing by default attribute definitions in attribute-resolver.xml

CONTENT='\t<resolver:AttributeDefinition xsi:type="ad:Simple" id="mobileNumber" sourceAttributeID="mobile">\n
     \t\t   <resolver:Dependency ref="myLDAP" />\n
     \t\t   <resolver:AttributeEncoder xsi:type="enc:SAML1String" name="urn:mace:dir:attribute-def:mobile" encodeType="false" />\n
     \t\t   <resolver:AttributeEncoder xsi:type="enc:SAML2String" name="urn:oid:0.9.2342.19200300.100.1.41" friendlyName="mobile" encodeType="false" />\n
     \t</resolver:AttributeDefinition>\n
     \n
     \t<resolver:AttributeDefinition xsi:type="ad:Simple" id="locality" sourceAttributeID="l">\n
     \t\t   <resolver:Dependency ref="myLDAP" />\n
     \t\t   <resolver:AttributeEncoder xsi:type="enc:SAML1String" name="urn:mace:dir:attribute-def:l" encodeType="false" />\n
     \t\t   <resolver:AttributeEncoder xsi:type="enc:SAML2String" name="urn:oid:2.5.4.7" friendlyName="l" encodeType="false" />\n
     \t</resolver:AttributeDefinition>\n
     \n
     \t<resolver:AttributeDefinition xsi:type="ad:Simple" id="title" sourceAttributeID="title">\n
     \t\t   <resolver:Dependency ref="myLDAP" />\n
     \t\t   <resolver:AttributeEncoder xsi:type="enc:SAML1String" name="urn:mace:dir:attribute-def:title" encodeType="false" />\n
     \t\t   <resolver:AttributeEncoder xsi:type="enc:SAML2String" name="urn:oid:2.5.4.12" friendlyName="title" encodeType="false" />\n
     \t</resolver:AttributeDefinition>\n'

C=$(echo $CONTENT | sed 's/\//\\\//g')

sed -i "/<resolver:AttributeDefinition xsi:type=\"ad:Simple\" id=\"uid\" sourceAttributeID=\"uid\">/ s/.*/${C}\n&/" "${IDP_ATTR_RESOLVER_FILE}"

sed -i '/<!--/,/-->/d' "${IDP_ATTR_RESOLVER_FILE}"

#cat "${IDP_ATTR_RESOLVER_FILE}"

# append dynamicWellKnown MetadataProvider in metadata-providers.xml 

cat > "${IDP_META_PROVIDERS_FILE}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!-- This file is an EXAMPLE metadata configuration file. -->
<MetadataProvider id="ShibbolethMetadata" xsi:type="ChainingMetadataProvider"
    xmlns="urn:mace:shibboleth:2.0:metadata"
    xmlns:resource="urn:mace:shibboleth:2.0:resource"
    xmlns:security="urn:mace:shibboleth:2.0:security"
    xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="urn:mace:shibboleth:2.0:metadata http://shibboleth.net/schema/idp/shibboleth-metadata.xsd
                        urn:mace:shibboleth:2.0:resource http://shibboleth.net/schema/idp/shibboleth-resource.xsd 
                        urn:mace:shibboleth:2.0:security http://shibboleth.net/schema/idp/shibboleth-security.xsd
                        urn:oasis:names:tc:SAML:2.0:metadata http://docs.oasis-open.org/security/saml/v2.0/saml-schema-metadata-2.0.xsd">
    <!-- ========================================================================================== -->
    <!--                             Metadata Configuration                                         -->
    <!--                                                                                            -->
    <!--  Below you place the mechanisms which define how to load the metadata for the SP you will  -->
    <!--  provide a service to.                                                                     -->
    <!--                                                                                            -->
    <!--  Two examples are provided.  The Shibboleth Documentation at                               -->
    <!--  https://wiki.shibboleth.net/confluence/display/IDP30/MetadataConfiguration                -->
    <!--  provides more details.                                                                    --> 
    <!--                                                                                            -->
    <!--  NOTE.  This file SHOULD NOT contain the metadata for this IdP.                            -->
    <!--                                                                                            -->
    <!-- ========================================================================================== -->

    <MetadataProvider id="TestSP" xsi:type="FilesystemMetadataProvider" metadataFile="%{idp.home}/metadata/sp-metadata.xml"/>
    <MetadataProvider id="TestSimpleSAMLphp" xsi:type="FilesystemMetadataProvider" metadataFile="%{idp.home}/metadata/ssp-metadata.xml"/>
    <MetadataProvider id="TestLocalhostHttp" xsi:type="FilesystemMetadataProvider" metadataFile="%{idp.home}/metadata/sp-onlyoffice1.xml"/>
    <MetadataProvider id="TestLocalhostHttps" xsi:type="FilesystemMetadataProvider" metadataFile="%{idp.home}/metadata/sp-onlyoffice2.xml"/>

    <MetadataProvider id="dynamicWellKnown" xsi:type="DynamicHTTPMetadataProvider" />

</MetadataProvider>
EOF

#cat "${IDP_META_PROVIDERS_FILE}"

# append SP_DEV_HTTP_META_FILE

cat > "${SP_DEV_HTTP_META_FILE}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<EntityDescriptor xmlns="urn:oasis:names:tc:SAML:2.0:metadata" entityID="http://localhost/sso/metadata">
    <SPSSODescriptor AuthnRequestsSigned="true" WantAssertionsSigned="true" protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
        <KeyDescriptor use="signing">
            <ds:KeyInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
                <ds:X509Data>
                    <ds:X509Certificate>MIIDFDCCAfygAwIBAgIVAN3vv+b7KN5Se9m1RZsCllp/B/hdMA0GCSqGSIb3DQEBCwUAMBUxEzARBgNVBAMMCmlkcHRlc3RiZWQwHhcNMTUxMjExMDIyMDE0WhcNMzUxMjExMDIyMDE0WjAVMRMwEQYDVQQDDAppZHB0ZXN0YmVkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAh91caeY0Q85uhaUyqFwP2bMjwMFxMzRlAoqBHd7gu6eo4duaeLz1BaoR2XTBpNNvFR5oHH+TkKahVDGeH5+kcnIpxI8JPdsZml1srvf2Z6dzJsulJZUdpqnngycTkGtZgEoC1vmYVky2BSAIIifmdh6s0epbHnMGLsHzMKfJCb/Q6dYzRWTCPtzE2VMuQqqWgeyMr7u14x/Vqr9RPEFsgY8GIu5jzB6AyUIwrLg+MNkv6aIdcHwxYTGL7ijfy6rSWrgBflQoYRYNEnseK0ZHgJahz4ovCag6wZAoPpBsuYlY7lEr89Ucb6NHx3uqGMsXlDFdE4QwfDLLhCYHPvJ0uwIDAQABo1swWTAdBgNVHQ4EFgQUAkOgED3iYdmvQEOMm6u/JmD/UTQwOAYDVR0RBDEwL4IKaWRwdGVzdGJlZIYhaHR0cHM6Ly9pZHB0ZXN0YmVkL2lkcC9zaGliYm9sZXRoMA0GCSqGSIb3DQEBCwUAA4IBAQBIdd4YWlnvJjql8+zKKgmWgIY7U8DA8e6QcbAf8f8cdE33RSnjI63Xsv/y9GfmbAVAD6RIAXPFFeRYJ08GOxGI9axfNaKdlsklJ9bk4ducHqgCSWYVer3sRQBjxyOfSTvk9YCJvdJVQRJLcCvxwKakFCsOSnV3t9OvN86Ak+fKPVB5j2fM/0fZKqjn3iqgdNPTLXPsuJLJO5lITRiBa4onmVelAiCstI9PQiaEck+oAHnMTnC9JE/BDHv3e4rwq3LznlqPw0GSd7xqNTdMDwNOWjkuOr3sGpWS8ms/ZHHXV1Vd22uPe70is00xrv14zLifcc8oj5DYzOhYRifRXgHX</ds:X509Certificate>
                </ds:X509Data>
            </ds:KeyInfo>
        </KeyDescriptor>
        <KeyDescriptor use="encryption">
            <ds:KeyInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
                <ds:X509Data>
                    <ds:X509Certificate>MIIDFDCCAfygAwIBAgIVAN3vv+b7KN5Se9m1RZsCllp/B/hdMA0GCSqGSIb3DQEBCwUAMBUxEzARBgNVBAMMCmlkcHRlc3RiZWQwHhcNMTUxMjExMDIyMDE0WhcNMzUxMjExMDIyMDE0WjAVMRMwEQYDVQQDDAppZHB0ZXN0YmVkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAh91caeY0Q85uhaUyqFwP2bMjwMFxMzRlAoqBHd7gu6eo4duaeLz1BaoR2XTBpNNvFR5oHH+TkKahVDGeH5+kcnIpxI8JPdsZml1srvf2Z6dzJsulJZUdpqnngycTkGtZgEoC1vmYVky2BSAIIifmdh6s0epbHnMGLsHzMKfJCb/Q6dYzRWTCPtzE2VMuQqqWgeyMr7u14x/Vqr9RPEFsgY8GIu5jzB6AyUIwrLg+MNkv6aIdcHwxYTGL7ijfy6rSWrgBflQoYRYNEnseK0ZHgJahz4ovCag6wZAoPpBsuYlY7lEr89Ucb6NHx3uqGMsXlDFdE4QwfDLLhCYHPvJ0uwIDAQABo1swWTAdBgNVHQ4EFgQUAkOgED3iYdmvQEOMm6u/JmD/UTQwOAYDVR0RBDEwL4IKaWRwdGVzdGJlZIYhaHR0cHM6Ly9pZHB0ZXN0YmVkL2lkcC9zaGliYm9sZXRoMA0GCSqGSIb3DQEBCwUAA4IBAQBIdd4YWlnvJjql8+zKKgmWgIY7U8DA8e6QcbAf8f8cdE33RSnjI63Xsv/y9GfmbAVAD6RIAXPFFeRYJ08GOxGI9axfNaKdlsklJ9bk4ducHqgCSWYVer3sRQBjxyOfSTvk9YCJvdJVQRJLcCvxwKakFCsOSnV3t9OvN86Ak+fKPVB5j2fM/0fZKqjn3iqgdNPTLXPsuJLJO5lITRiBa4onmVelAiCstI9PQiaEck+oAHnMTnC9JE/BDHv3e4rwq3LznlqPw0GSd7xqNTdMDwNOWjkuOr3sGpWS8ms/ZHHXV1Vd22uPe70is00xrv14zLifcc8oj5DYzOhYRifRXgHX</ds:X509Certificate>
                </ds:X509Data>
            </ds:KeyInfo>
        </KeyDescriptor>
        <SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="http://localhost/sso/slo/callback"/>
        <SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="http://localhost/sso/slo/callback"/>
        <NameIDFormat>urn:oasis:names:tc:SAML:2.0:nameid-format:transient</NameIDFormat>
        <AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="http://localhost/sso/acs" index="0"/>
        <AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="http://localhost/sso/acs" index="1"/>
        <AttributeConsumingService>
            <RequestedAttribute FriendlyName="mail" Name="urn:oid:0.9.2342.19200300.100.1.3" NameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:uri"/>
            <RequestedAttribute FriendlyName="givenName" Name="urn:oid:2.5.4.42" NameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:uri"/>
            <RequestedAttribute FriendlyName="sn" Name="urn:oid:2.5.4.4" NameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:uri"/>
            <RequestedAttribute FriendlyName="mobile" Name="urn:oid:0.9.2342.19200300.100.1.41" NameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:uri"/>
            <RequestedAttribute FriendlyName="title" Name="urn:oid:2.5.4.12" NameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:uri"/>
            <RequestedAttribute FriendlyName="l" Name="urn:oid:2.5.4.7" NameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:uri"/>
        </AttributeConsumingService>
    </SPSSODescriptor>
    <Organization xml:lang="en-US">
        <OrganizationName>Ascensio System SIA</OrganizationName>
        <OrganizationDisplayName>Onlyoffice</OrganizationDisplayName>
        <OrganizationURL>http://www.onlyoffice.com</OrganizationURL>
    </Organization>
    <ContactPerson contactType="support">
        <GivenName>Support</GivenName>
        <EmailAddress>support@onlyoffice.com</EmailAddress>
    </ContactPerson>
</EntityDescriptor>
EOF

# append SP_DEV_HTTPS_META_FILE

cat > "${SP_DEV_HTTPS_META_FILE}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<EntityDescriptor xmlns="urn:oasis:names:tc:SAML:2.0:metadata" entityID="https://localhost/sso/metadata">
    <SPSSODescriptor AuthnRequestsSigned="true" WantAssertionsSigned="true" protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
        <KeyDescriptor use="signing">
            <ds:KeyInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
                <ds:X509Data>
                    <ds:X509Certificate>MIIDFDCCAfygAwIBAgIVAN3vv+b7KN5Se9m1RZsCllp/B/hdMA0GCSqGSIb3DQEBCwUAMBUxEzARBgNVBAMMCmlkcHRlc3RiZWQwHhcNMTUxMjExMDIyMDE0WhcNMzUxMjExMDIyMDE0WjAVMRMwEQYDVQQDDAppZHB0ZXN0YmVkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAh91caeY0Q85uhaUyqFwP2bMjwMFxMzRlAoqBHd7gu6eo4duaeLz1BaoR2XTBpNNvFR5oHH+TkKahVDGeH5+kcnIpxI8JPdsZml1srvf2Z6dzJsulJZUdpqnngycTkGtZgEoC1vmYVky2BSAIIifmdh6s0epbHnMGLsHzMKfJCb/Q6dYzRWTCPtzE2VMuQqqWgeyMr7u14x/Vqr9RPEFsgY8GIu5jzB6AyUIwrLg+MNkv6aIdcHwxYTGL7ijfy6rSWrgBflQoYRYNEnseK0ZHgJahz4ovCag6wZAoPpBsuYlY7lEr89Ucb6NHx3uqGMsXlDFdE4QwfDLLhCYHPvJ0uwIDAQABo1swWTAdBgNVHQ4EFgQUAkOgED3iYdmvQEOMm6u/JmD/UTQwOAYDVR0RBDEwL4IKaWRwdGVzdGJlZIYhaHR0cHM6Ly9pZHB0ZXN0YmVkL2lkcC9zaGliYm9sZXRoMA0GCSqGSIb3DQEBCwUAA4IBAQBIdd4YWlnvJjql8+zKKgmWgIY7U8DA8e6QcbAf8f8cdE33RSnjI63Xsv/y9GfmbAVAD6RIAXPFFeRYJ08GOxGI9axfNaKdlsklJ9bk4ducHqgCSWYVer3sRQBjxyOfSTvk9YCJvdJVQRJLcCvxwKakFCsOSnV3t9OvN86Ak+fKPVB5j2fM/0fZKqjn3iqgdNPTLXPsuJLJO5lITRiBa4onmVelAiCstI9PQiaEck+oAHnMTnC9JE/BDHv3e4rwq3LznlqPw0GSd7xqNTdMDwNOWjkuOr3sGpWS8ms/ZHHXV1Vd22uPe70is00xrv14zLifcc8oj5DYzOhYRifRXgHX</ds:X509Certificate>
                </ds:X509Data>
            </ds:KeyInfo>
        </KeyDescriptor>
        <KeyDescriptor use="encryption">
            <ds:KeyInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
                <ds:X509Data>
                    <ds:X509Certificate>MIIDFDCCAfygAwIBAgIVAN3vv+b7KN5Se9m1RZsCllp/B/hdMA0GCSqGSIb3DQEBCwUAMBUxEzARBgNVBAMMCmlkcHRlc3RiZWQwHhcNMTUxMjExMDIyMDE0WhcNMzUxMjExMDIyMDE0WjAVMRMwEQYDVQQDDAppZHB0ZXN0YmVkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAh91caeY0Q85uhaUyqFwP2bMjwMFxMzRlAoqBHd7gu6eo4duaeLz1BaoR2XTBpNNvFR5oHH+TkKahVDGeH5+kcnIpxI8JPdsZml1srvf2Z6dzJsulJZUdpqnngycTkGtZgEoC1vmYVky2BSAIIifmdh6s0epbHnMGLsHzMKfJCb/Q6dYzRWTCPtzE2VMuQqqWgeyMr7u14x/Vqr9RPEFsgY8GIu5jzB6AyUIwrLg+MNkv6aIdcHwxYTGL7ijfy6rSWrgBflQoYRYNEnseK0ZHgJahz4ovCag6wZAoPpBsuYlY7lEr89Ucb6NHx3uqGMsXlDFdE4QwfDLLhCYHPvJ0uwIDAQABo1swWTAdBgNVHQ4EFgQUAkOgED3iYdmvQEOMm6u/JmD/UTQwOAYDVR0RBDEwL4IKaWRwdGVzdGJlZIYhaHR0cHM6Ly9pZHB0ZXN0YmVkL2lkcC9zaGliYm9sZXRoMA0GCSqGSIb3DQEBCwUAA4IBAQBIdd4YWlnvJjql8+zKKgmWgIY7U8DA8e6QcbAf8f8cdE33RSnjI63Xsv/y9GfmbAVAD6RIAXPFFeRYJ08GOxGI9axfNaKdlsklJ9bk4ducHqgCSWYVer3sRQBjxyOfSTvk9YCJvdJVQRJLcCvxwKakFCsOSnV3t9OvN86Ak+fKPVB5j2fM/0fZKqjn3iqgdNPTLXPsuJLJO5lITRiBa4onmVelAiCstI9PQiaEck+oAHnMTnC9JE/BDHv3e4rwq3LznlqPw0GSd7xqNTdMDwNOWjkuOr3sGpWS8ms/ZHHXV1Vd22uPe70is00xrv14zLifcc8oj5DYzOhYRifRXgHX</ds:X509Certificate>
                </ds:X509Data>
            </ds:KeyInfo>
        </KeyDescriptor>
        <SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="https://localhost/sso/slo/callback"/>
        <SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="https://localhost/sso/slo/callback"/>
        <NameIDFormat>urn:oasis:names:tc:SAML:2.0:nameid-format:transient</NameIDFormat>
        <AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="https://localhost/sso/acs" index="0"/>
        <AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="https://localhost/sso/acs" index="1"/>
        <AttributeConsumingService>
            <RequestedAttribute FriendlyName="mail" Name="urn:oid:0.9.2342.19200300.100.1.3" NameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:uri"/>
            <RequestedAttribute FriendlyName="givenName" Name="urn:oid:2.5.4.42" NameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:uri"/>
            <RequestedAttribute FriendlyName="sn" Name="urn:oid:2.5.4.4" NameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:uri"/>
            <RequestedAttribute FriendlyName="mobile" Name="urn:oid:0.9.2342.19200300.100.1.41" NameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:uri"/>
            <RequestedAttribute FriendlyName="title" Name="urn:oid:2.5.4.12" NameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:uri"/>
            <RequestedAttribute FriendlyName="l" Name="urn:oid:2.5.4.7" NameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:uri"/>
        </AttributeConsumingService>
    </SPSSODescriptor>
    <Organization xml:lang="en-US">
        <OrganizationName>Ascensio System SIA</OrganizationName>
        <OrganizationDisplayName>Onlyoffice</OrganizationDisplayName>
        <OrganizationURL>http://www.onlyoffice.com</OrganizationURL>
    </Organization>
    <ContactPerson contactType="support">
        <GivenName>Support</GivenName>
        <EmailAddress>support@onlyoffice.com</EmailAddress>
    </ContactPerson>
</EntityDescriptor>
EOF

# change scope
sed -i 's/idp.scope= example.org/idp.scope= '"${IDP_DOMAIN}"'/g' "${IDP_PROPERTIES_FILE}"
# show detailed errors 
sed -i 's/#idp.errors.detailed = false/idp.errors.detailed = true/g' "${IDP_PROPERTIES_FILE}"
# enable sessions
sed -i 's/#idp.session.enabled = true/idp.session.enabled = true/g' "${IDP_PROPERTIES_FILE}"
# track sp sessions
sed -i 's/#idp.session.trackSPSessions = false/idp.session.trackSPSessions = true/g' "${IDP_PROPERTIES_FILE}"

if [ "$ENABLE_SLO" == "true" ]; then
    # enable SLO in idp.properties according to https://wiki.shibboleth.net/confluence/display/IDP30/LogoutConfiguration

    sed -i 's/#idp.logout.elaboration = false/idp.logout.elaboration = true/g' "${IDP_PROPERTIES_FILE}"
    sed -i 's/#idp.logout.authenticated = true/idp.logout.authenticated = false/g' "${IDP_PROPERTIES_FILE}"
    sed -i 's/#idp.session.secondaryServiceIndex = false/idp.session.secondaryServiceIndex = true/g' "${IDP_PROPERTIES_FILE}"
    sed -i 's/p:authorizedToProxy=\"false\" \/>/p:authorizedToProxy=\"false\"\n\t\t      p:singleLogoutParticipant=\"true\" \/>/g' "${IDP_CAS_PROTOCOL_FILE}"

    # remove comments from defaul idp-metadata.xml and restore SLO endpoints

    sed -i '/<!--/,/-->/d' "${IDP_META_FILE}"

    CONTENT='\t<SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="https://'"${IDP_DOMAIN}"'/idp/profile/SAML2/Redirect/SLO"/>\n
             \t<SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="https://'"${IDP_DOMAIN}"'/idp/profile/SAML2/POST/SLO"/>\n
             \t<SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST-SimpleSign" Location="https://'"${IDP_DOMAIN}"'/idp/profile/SAML2/POST-SimpleSign/SLO"/>\n
             \t<SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:SOAP" Location="https://'"${IDP_DOMAIN}"':8443/idp/profile/SAML2/SOAP/SLO"/>\n'

    C=$(echo $CONTENT | sed 's/\//\\\//g')

    sed -i "/<NameIDFormat>urn:mace:shibboleth:1.0:nameIdentifier<\/NameIDFormat>/ s/.*/${C}\n&/" "${IDP_META_FILE}"

    #cat "${IDP_META_FILE}"
fi

# write new relying-party.xml
cat > "${IDP_RELYING_PARTY_FILE}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:context="http://www.springframework.org/schema/context"
       xmlns:util="http://www.springframework.org/schema/util"
       xmlns:p="http://www.springframework.org/schema/p"
       xmlns:c="http://www.springframework.org/schema/c"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd
                           http://www.springframework.org/schema/context http://www.springframework.org/schema/context/spring-context.xsd
                           http://www.springframework.org/schema/util http://www.springframework.org/schema/util/spring-util.xsd"

       default-init-method="initialize"
       default-destroy-method="destroy">

    <!--
    Unverified RP configuration, defaults to no support for any profiles. Add <ref> elements to the list
    to enable specific default profile settings (as below), or create new beans inline to override defaults.
    
    "Unverified" typically means the IdP has no metadata, or equivalent way of assuring the identity and
    legitimacy of a requesting system. To run an "open" IdP, you can enable profiles here.
    -->
    <bean id="shibboleth.UnverifiedRelyingParty" parent="RelyingParty">
        <property name="profileConfigurations">
            <list>
            <!-- <bean parent="SAML2.SSO" p:encryptAssertions="false" /> -->
            </list>
        </property>
    </bean>

    <!--
    Default configuration, with default settings applied for all profiles, and enables
    the attribute-release consent flow.
    -->
    <bean id="shibboleth.DefaultRelyingParty" parent="RelyingParty">
        <property name="profileConfigurations">
            <list>
                <bean parent="Shibboleth.SSO" p:postAuthenticationFlows="attribute-release" />
                <ref bean="SAML1.AttributeQuery" />
                <ref bean="SAML1.ArtifactResolution" />
                <bean parent="SAML2.SSO" p:postAuthenticationFlows="attribute-release" />
                <ref bean="SAML2.ECP" />
                <ref bean="SAML2.Logout" />
                <ref bean="SAML2.AttributeQuery" />
                <ref bean="SAML2.ArtifactResolution" />
                <ref bean="CAS.LoginConfiguration" />
                <ref bean="CAS.ValidateConfiguration" />
            </list>
        </property>
    </bean>

    <!-- Container for any overrides you want to add. -->

    <util:list id="shibboleth.RelyingPartyOverrides">
        <bean parent="RelyingPartyByName" c:relyingPartyIds="https://sp.ccc.local/shibboleth">
            <property name="profileConfigurations">
                <list>
                    <bean parent="SAML2.SSO" p:encryptAssertions="false" p:postAuthenticationFlows="attribute-release" />
                </list>
            </property>
        </bean>
        <bean parent="RelyingPartyByName" c:relyingPartyIds="#{{'http://$SP_DOMAIN/sso/metadata', 'https://$SP_DOMAIN/sso/metadata', 'http://localhost/sso/metadata', 'https://localhost/sso/metadata'}}">
            <property name="profileConfigurations">
                <list>
                    <bean parent="SAML2.SSO" p:encryptAssertions="true" p:postAuthenticationFlows="attribute-release" />
                    <bean parent="SAML2.Logout" />
                </list>
            </property>
        </bean>
    </util:list>
</beans>
EOF

# write ldap users in ldap/users.ldif
cat > "${LDAP_USERS_FILE}" << EOF
dn: cn=admin,dc=$D2,dc=$D1
objectClass: simpleSecurityObject
objectClass: organizationalRole
cn: admin
userPassword: password
description: LDAP administrator


dn: uid=student1,ou=People,dc=$D2,dc=$D1
objectClass: organizationalPerson
objectClass: person
objectClass: top
objectClass: inetOrgPerson
givenName: Stud
uid: student1
sn: Ent
cn: Stud Ent
mail: student1@$IDP_DOMAIN
title: Student
mobile: +4(111)999-99-99
l: office 305
userPassword: password

dn: uid=student2,ou=People,dc=$D2,dc=$D1
objectClass: organizationalPerson
objectClass: person
objectClass: top
objectClass: inetOrgPerson
uid: student2
sn: Ent
cn: Stud2 Ent
mail: student2@$IDP_DOMAIN
title: Student
mobile: +4(222)999-99-99
l: office 305
userPassword: password

dn: uid=student3,ou=People,dc=$D2,dc=$D1
objectClass: organizationalPerson
objectClass: person
objectClass: top
objectClass: inetOrgPerson
givenName: Stud3&#246;
uid: student3
sn: Entö
cn: Stud3 Ent
mail: student3@$IDP_DOMAIN
title: Student
mobile: +4(333)999-99-99
l: office 305
userPassword: password

dn: uid=staff1,ou=People,dc=$D2,dc=$D1
objectClass: organizationalPerson
objectClass: person
objectClass: top
objectClass: inetOrgPerson
givenName: St
uid: staff1
sn: aff
cn: St aff
mail: staff1@$IDP_DOMAIN
userPassword: password
EOF

# build, start and wait for started Shibboleth IDP with other containers

echo "Build containers for Shibboleth..."
docker-compose -f /app/dockerized-idp-testbed-master/docker-compose.yml build

echo "Start containers for Shibboleth..."
docker-compose -f /app/dockerized-idp-testbed-master/docker-compose.yml up -d

echo ""
echo "Shibboleth is starting... Please, wait for \"Server:main: Started\" string or press Ctrl+C to exit"
docker-compose -f /app/dockerized-idp-testbed-master/docker-compose.yml logs -f | grep "Server:main: Started @"

