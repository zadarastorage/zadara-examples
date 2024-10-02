#!/usr/bin/python3
# -*- coding: utf-8 -*-
# flake8: noqa

# Make sure pyudev is upgraded to at least 0.21

import sys
import os
import requests
import pyudev
import boto3
from retrying import retry
import logging
import logging.handlers


@retry(wait_exponential_multiplier=1000, wait_exponential_max=10000, stop_max_attempt_number=5)
def main(kernel_name):
    _log_setup()
    logging.info('[%s] New Device', kernel_name)
    serial = _get_device_serial(kernel_name)
    logging.info('[%s] Serial is %s', kernel_name, serial)
    device_name = _try_extract_device_name_from_serial(kernel_name, serial)
    if not device_name:
        device_name = _try_extract_device_name_from_api(kernel_name, serial)

    if device_name and device_name != kernel_name:
        print(os.path.relpath(device_name, '/dev'))


def _log_setup():
    log_handler = logging.handlers.RotatingFileHandler('/var/log/zadara_disk_mapper.log', maxBytes=20000, backupCount=5)
    logger = logging.getLogger()
    logger.addHandler(log_handler)
    logger.setLevel(logging.INFO)


def _get_device_serial(kernel_name):
    context = pyudev.Context()
    device = pyudev.Devices.from_name(context, 'block', kernel_name)
    serial = device.attributes.asstring('serial')
    return serial.replace('-', '')


def _try_extract_device_name_from_serial(kernel_name, serial):
    if '-' in serial or '00' not in serial:
        return None
    logging.info('[%s] trying to get device name from Serial: %s', kernel_name, serial)
    hex_device_name = serial.split('00')[0]
    chars = [hex_device_name[i:i + 2] for i in range(0, len(hex_device_name), 2)]
    device_name = ''.join([chr(int(c, 16)) for c in chars])
    logging.info('[%s] device name for serial %s is %s', kernel_name, serial, device_name)
    return '/dev/{}'.format(device_name)


def _get_device_name_from_api(instance_id, region, endpoint, kernel_name, serial):
    logging.info('[%s] trying to get device name from API: %s', kernel_name, serial)
    client = boto3.client('ec2', region_name=region, endpoint_url=endpoint)
    response = client.describe_volumes(Filters=[{'Name': 'attachment.instance-id', 'Values': [instance_id]}])
    volumes = response['Volumes']
    for volume in volumes:
        vol_id = volume['VolumeId'].split('-')[1]
        if vol_id.startswith(serial):
            device_name = volume['Attachments'][0]['Device']
            logging.info('[%s] device name for serial %s is %s', kernel_name, serial, device_name)
            return device_name
    return ''


def _try_extract_device_name_from_api(kernel_name, serial):
    logging.info('[%s] Trying to extract device name from serial', kernel_name)
    instance_id = requests.get('http://169.254.169.254/latest/meta-data/instance-id').content.decode('utf-8')
    logging.info('[%s] instance ID is %s', kernel_name, instance_id)
    availability_zone = requests.get('http://169.254.169.254/latest/meta-data/placement/availability-zone').content.decode('utf-8')
    endpoint = requests.get('http://169.254.169.254/openstack/latest/meta_data.json').json()['cluster_url']
    device_name = _get_device_name_from_api(instance_id, availability_zone, f'{endpoint}/api/v2/aws/ec2/', kernel_name, serial)
    logging.info('[%s] Device Name is %s', kernel_name, device_name)
    return device_name


if __name__ == '__main__':
    os.environ['AWS_CA_BUNDLE'] = '/etc/ssl/certs/ca-certificates.crt'
    os.environ['AWS_METADATA_SERVICE_TIMEOUT'] = '5'
    os.environ['AWS_METADATA_SERVICE_NUM_ATTEMPTS'] = '3'
    main(sys.argv[1])
