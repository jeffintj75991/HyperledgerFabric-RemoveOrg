
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_ID=cli
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051
export CHANNEL_NAME=master-channel

expexport CORE_PEER_MSPCONFIGPATH=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
ort ORDERER_CA=${PWD}/artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

#Step 1: Get the latest configuration block . We decode the file and only extract the portion useful into the config.json file.

peer channel fetch config config_block.pb -o localhost:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA

configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json

#Step 2: Remove Org3MSP from config.json and keep the result in modified_config.json.

jq 'del(.channel_group.groups.Application.groups.Org3MSP)' config.json > modified_config.json

#Step 3: Encode both config.json and modified_config.json files to PB format. 
#        Compute the difference of the two files, saved as update.pb.

configtxlator proto_encode --input config.json --type common.Config --output config.pb

configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb

configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output update.pb

#Step 4: Add back envelope for update.pb, which first decode it into update.json, add the envelope,
#       and the result is encoded back to update_in_envelope.pb.

configtxlator proto_decode --input update.pb --type common.ConfigUpdate | jq . > update.json

echo '{"payload":{"header":{"channel_header":{"channel_id":"master-channel", "type":2}},"data":{"config_update":'$(cat update.json)'}}}' | jq . > update_in_envelope.json

configtxlator proto_encode --input update_in_envelope.json --type common.Envelope --output update_in_envelope.pb

#Step 5: Sign the update_in_envelope.pb by Org1. Org2 sends this file as update (which includes Org2’s signature as well).

peer channel signconfigtx -f update_in_envelope.pb

peer channel update -f update_in_envelope.pb -c $CHANNEL_NAME -o localhost:7050 --tls --cafile $ORDERER_CA

#commands to check whether the operation was successful or not

# docker exec -it peer0.org1.example.com sh
# peer channel getinfo -c master-channel

# docker exec -it peer0.org2.example.com sh
# peer channel getinfo -c master-channel

# #Block height will be one less than other orgs
# docker exec -it peer0.org3.example.com sh
# peer channel getinfo -c master-channel

# docker exec -it peer0.org4.example.com sh
# peer channel getinfo -c master-channel

