import { RemovalPolicy, Stack, StackProps, CfnOutput } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as rds from 'aws-cdk-lib/aws-rds';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';

export class MysqldatabaseStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    // The code that defines your stack goes here
    const stackName = Stack.of(this).stackName;
    const dbname = 'mydb';
    const dbuser = 'mydbuser';
    const cidr = '10.10.0.0/24';
    const eksCidr = '172.11.0.0/16';

    // Create VPC
    const vpc = new ec2.Vpc(this, 'vpc', {
      cidr,
      maxAzs: 2,
      natGateways: 1,
      subnetConfiguration: [
        {
          name: 'public',
          subnetType: ec2.SubnetType.PUBLIC,
        },
        {
          name: 'private',
          subnetType: ec2.SubnetType.PRIVATE_WITH_NAT,
        }
      ]
    });

    // Prepare DB Subnet Group
    const dbSubnetGroup = new rds.SubnetGroup(this, `${stackName}-dbSubnetGroup`, {
      description: "db subnet group",
      vpc: vpc,
      vpcSubnets: {
        subnetType: ec2.SubnetType.PRIVATE_WITH_NAT
      }
    });

    // Create Security Group Database
    const dbSecurityGroup = new ec2.SecurityGroup(this, `${stackName}-DbSecurityGroup`,{
      vpc: vpc
    });
    dbSecurityGroup.addIngressRule(
      ec2.Peer.ipv4(vpc.vpcCidrBlock),
      ec2.Port.tcp(3306),
      'allow rds from within vpc network'
    );
    dbSecurityGroup.addIngressRule(
      ec2.Peer.ipv4(eksCidr),
      ec2.Port.tcp(3306),
      'allow rds from eks network'
    );

    // Prepare Secret for Database Username Password
    const dbSecret = new secretsmanager.Secret(this, `${stackName}-dbSecret`, {
      generateSecretString:{
          secretStringTemplate: JSON.stringify({
              username: dbuser,
          }),
          excludePunctuation: true,
          includeSpace: false,
          generateStringKey: "password"
      }
    });

    // Create RDS MySQL database
    const securityGroup: ec2.ISecurityGroup = dbSecurityGroup;
    const dbhost = new rds.DatabaseInstance(this, 'rds', {
      engine: rds.DatabaseInstanceEngine.mysql(
        {
          version: rds.MysqlEngineVersion.VER_5_7_30,
        }),
      credentials: rds.Credentials.fromSecret(dbSecret),
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.BURSTABLE3, ec2.InstanceSize.SMALL),
      allocatedStorage: 5,
      instanceIdentifier: `${stackName}-mysql-database`,
      databaseName: dbname,
      vpc: vpc,
      subnetGroup: dbSubnetGroup,
      securityGroups: [securityGroup],
      deleteAutomatedBackups: true,
      removalPolicy: RemovalPolicy.DESTROY
    });

    new CfnOutput(this, 'dbUsername', {value: dbuser});
    new CfnOutput(this, 'dbName', {value: dbname});
    new CfnOutput(this, 'vpcId', {value: vpc.vpcId});
    new CfnOutput(this, 'dbHost', {value: dbhost.dbInstanceEndpointAddress});
    new CfnOutput(this, 'dbSecurityGroup', {value: dbSecurityGroup.securityGroupId});
    new CfnOutput(this, 'secretArn', {value: dbSecret.secretArn});
  }
}
