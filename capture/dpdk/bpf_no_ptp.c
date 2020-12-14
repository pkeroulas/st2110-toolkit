/* SPDX-License-Identifier: BSD-3-Clause
 * Copyright(c) 2018 Intel Corporation
 */

/*
 * eBPF program sample to filter ptp traffic (dst 224.0.1.129)
 *
 * To compile on x86:
 * install ibc6-dev-i386
 * clang -O2 -U __GNUC__ -I /usr/include/x86_64-linux-gnu/ -target bpf -c bpf_no_ptp.c
 *
 */

#include <stdint.h>
#include <net/ethernet.h>
#include <netinet/ip.h>
#include <netinet/udp.h>
#include <arpa/inet.h>

uint64_t
entry(void *pkt)
{
	struct ether_header *ether_header = (void *)pkt;

	if (ether_header->ether_type != htons(0x0800))
		return 0;

	struct iphdr *iphdr = (void *)(ether_header + 1);
	if (iphdr->protocol != 17 || (iphdr->frag_off & 0x1ffff) != 0 || iphdr->daddr == htonl(0xE0000181))
		return 0;

	return 1;
}
