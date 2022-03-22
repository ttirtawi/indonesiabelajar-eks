#!/bin/bash
function vpcpeering(){
	VPC1CIDR=$(aws ec2 describe-vpcs --vpc-ids $VPC1 --query 'Vpcs[].CidrBlock' --output text)
	VPC2CIDR=$(aws ec2 describe-vpcs --vpc-ids $VPC2 --query 'Vpcs[].CidrBlock' --output text)
	
	SUBNETVPC1=$(aws ec2 describe-subnets --query 'Subnets[?VpcId == `'${VPC1}'`].SubnetId' --output text)
	SUBNETVPC2=$(aws ec2 describe-subnets --query 'Subnets[?VpcId == `'${VPC2}'`].SubnetId' --output text)
	
	# Validate if existing peering exist
	
	PEERING=$(aws ec2 describe-vpc-peering-connections --filters Name=status-code,Values=active Name=requester-vpc-info.vpc-id,Values=${VPC1}  Name=accepter-vpc-info.vpc-id,Values=${VPC2}  --query 'VpcPeeringConnections[].VpcPeeringConnectionId' --output text)
	
	if [ $ACTION == "CREATE" ]; then
	
		if [ -z $PEERING ]; then
			PEERING=$(aws ec2 create-vpc-peering-connection --vpc-id $VPC1 --peer-vpc-id $VPC2 | jq -r .VpcPeeringConnection.VpcPeeringConnectionId )
			echo "VPC Peering ID:" $PEERING
			echo "Accepting the peering, current status: "$(aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $PEERING | jq -r .VpcPeeringConnection.Status.Message)
			aws ec2 create-tags --resources $PEERING --tags Key=Name,Value=$PEERING_NAME
	
			echo +++++++++++++++++++++++++++++=
			echo "VPC1: "$VPC1;
			echo "CIDR VPC1: " $VPC1CIDR;
			
			DEFAULT_RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC1}" "Name=association.main,Values=true" --query 'RouteTables[].Associations[].RouteTableId' --output text)
			for i in $SUBNETVPC1
			do
			  RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC1}" --query 'RouteTables[].Associations[?SubnetId==`'${i}'`].RouteTableId'  --output text)
				if [[ -z $RT ]]; then
					RT=$DEFAULT_RT
				fi
			  echo $i " adding route to route table: " $RT: $(aws ec2 create-route --route-table-id $RT --vpc-peering-connection-id $PEERING --destination-cidr-block ${VPC2CIDR} --output text)
			  RT=""
			done
			DEFAULT_RT=""
			
			echo +++++++++++++++++++++++++++++=
			echo "VPC2: "$VPC2;
			echo "CIDR VPC2: " $VPC2CIDR;

			DEFAULT_RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC2}" "Name=association.main,Values=true" --query 'RouteTables[].Associations[].RouteTableId' --output text)
			for i in $SUBNETVPC2
			do
			  RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC2}" --query 'RouteTables[].Associations[?SubnetId==`'${i}'`].RouteTableId'  --output text)
        if [[ -z $RT ]]; then
					RT=$DEFAULT_RT
        fi
			  echo $i " adding route to route table: " $RT: $(aws ec2 create-route --route-table-id $RT --vpc-peering-connection-id $PEERING --destination-cidr-block ${VPC1CIDR} --output text)
			  RT=""
			done
			DEFAULT_RT=""
		else
			echo "Peering exist: "$PEERING
		fi
	
	elif [[ $ACTION == "DELETE" ]]; then
	
		if [ ! -z $PEERING ]; then
			echo "Deleting the peering";
	  	echo +++++++++++++++++++++++++++++=
	  	echo "VPC1: "$VPC1;
	  	echo "CIDR VPC1: " $VPC1CIDR;

			DEFAULT_RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC1}" "Name=association.main,Values=true" --query 'RouteTables[].Associations[].RouteTableId' --output text)
	  	for i in $SUBNETVPC1
	  	do
	  	  RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC1}" --query 'RouteTables[].Associations[?SubnetId==`'${i}'`].RouteTableId'  --output text)
				if [[ -z $RT ]]; then
          RT=$DEFAULT_RT
        fi
	  	  echo $i " deleting route from route table: " $RT $(aws ec2 delete-route --route-table-id $RT --destination-cidr-block ${VPC2CIDR} --output text)
	  	  RT=""
	  	done
			DEFAULT_RT=""
	
	  	echo +++++++++++++++++++++++++++++=
	  	echo "VPC2: "$VPC2;
	  	echo "CIDR VPC2: " $VPC2CIDR;
			DEFAULT_RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC2}" "Name=association.main,Values=true" --query 'RouteTables[].Associations[].RouteTableId' --output text)
	  	for i in $SUBNETVPC2
	  	do
	  	  RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC2}" --query 'RouteTables[].Associations[?SubnetId==`'${i}'`].RouteTableId'  --output text)
				if [[ -z $RT ]]; then
          RT=$DEFAULT_RT
        fi
	  	  echo $i " deleting route from route table: " $RT $(aws ec2 delete-route --route-table-id $RT --destination-cidr-block ${VPC1CIDR} --output text)
	  	  RT=""
	  	done
			DEFAULT_RT=""
	
	  	echo +++++++++++++++++++++++++++++=
			DELETE=$(aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id $PEERING --output text)
	
			if [ $DELETE ]; then
				echo "Peer "$PEERING" deleted succesfully"
			fi
		else
			echo "Peering doesn't exist"
		fi
	
	fi
}

while getopts s:d:n:a: flag
do
  case "${flag}" in
    s) VPC1=${OPTARG};;
    d) VPC2=${OPTARG};;
    n) PEERING_NAME=${OPTARG};;
    a) ACTION=${OPTARG};;
  esac
done

if [[ -z "${VPC1}" || -z "${VPC2}" || -z "${PEERING_NAME}" || -z "${ACTION}" ]]
then
  echo "Usage: ./createPeering.sh -s <requestor_vpc_id> -d <accepter_vpc_id> -n <peering_name> -a <DELETE|CREATE>"
else
  echo $VPC1
  echo $VPC2
  echo $PEERING_NAME
  echo $ACTION
  echo  "lets go"
  vpcpeering
fi
