/**
 * @file ilbc.c  Internet Low Bit Rate Codec (iLBC) audio codec
 *
 * Copyright (C) 2010 Alfred E. Heggestad
 */
#include <re.h>
#include <rem.h>
#include <baresip.h>
#include <iLBC_define.h>
#include <iLBC_decode.h>
#include <iLBC_encode.h>


/**
 * @defgroup ilbc ilbc
 *
 * iLBC audio codec
 *
 * This module implements the iLBC audio codec as defined in:
 *
 *     RFC 3951  Internet Low Bit Rate Codec (iLBC)
 *     RFC 3952  RTP Payload Format for iLBC Speech
 *
 * The iLBC source code is not included here, but can be downloaded from
 * http://ilbcfreeware.org/
 *
 * You can also use the source distributed by the Freeswitch project,
 * see www.freeswitch.org, and then freeswitch/libs/codec/ilbc.
 * Or you can look in the asterisk source code ...
 *
 *   mode=20  15.20 kbit/s  160samp  38bytes
 *   mode=30  13.33 kbit/s  240samp  50bytes
 */

enum {
	DEFAULT_MODE = 20, /* 20ms or 30ms */
	USE_ENHANCER = 1
};

struct auenc_state {
	iLBC_Enc_Inst_t enc;
	int mode;
	uint32_t enc_bytes;
};

struct audec_state {
	iLBC_Dec_Inst_t dec;
	int mode;
	uint32_t nsamp;
	size_t dec_bytes;
};


static char ilbc_fmtp[32];
/* Global pointer to the active encoder state for pragmatic encoder/decoder
 * matching when peers mis-advertise fmtp. This is a heuristic to avoid
 * packetization mismatch (e.g. peer advertises 30ms but sends 20ms).
 */
static struct auenc_state *g_aenc = NULL;

/* Per-decoder detection state (kept external because we cannot modify
 * struct audec_state). We keep a small linked list keyed by audec_state*.
 */
struct detect_node {
	struct detect_node *next;
	struct audec_state *dec;
	int detected_mode; /* last detected mode (20 or 30), 0 = none */
	int count;         /* consecutive detections of detected_mode */
};
static struct detect_node *det_list = NULL;

static struct detect_node *det_find(struct audec_state *st)
{
	struct detect_node *n = det_list;
	for (; n; n = n->next) {
		if (n->dec == st)
			return n;
	}
	return NULL;
}

static struct detect_node *det_add(struct audec_state *st)
{
	struct detect_node *n;

	n = mem_alloc(sizeof(*n), NULL);
	if (!n)
		return NULL;
	n->dec = st;
	n->detected_mode = 0;
	n->count = 0;
	n->next = det_list;
	det_list = n;
	return n;
}

static void det_remove(struct audec_state *st)
{
	struct detect_node *n = det_list, *prev = NULL;
	while (n) {
		if (n->dec == st) {
			if (prev)
				prev->next = n->next;
			else
				det_list = n->next;
			mem_deref(n);
			return;
		}
		prev = n;
		n = n->next;
	}
}


static void set_encoder_mode(struct auenc_state *st, int mode)
{
	if (st->mode == mode)
		return;

	info("ilbc: set iLBC encoder mode %dms\n", mode);

	st->mode = mode;

	switch (mode) {

	case 20:
		st->enc_bytes = NO_OF_BYTES_20MS;
		break;

	case 30:
		st->enc_bytes = NO_OF_BYTES_30MS;
		break;

	default:
		warning("ilbc: unknown encoder mode %d\n", mode);
		return;
	}

	st->enc_bytes = initEncode(&st->enc, mode);
}


static void set_decoder_mode(struct audec_state *st, int mode)
{
	if (st->mode == mode)
		return;

	info("ilbc: set iLBC decoder mode %dms (was %d)\n", mode, st->mode);

	st->mode = mode;

	switch (mode) {

	case 20:
		st->nsamp = BLOCKL_20MS;
		break;

	case 30:
		st->nsamp = BLOCKL_30MS;
		break;

	default:
		warning("ilbc: unknown decoder mode %d\n", mode);
		return;
	}

	info("ilbc: set_decoder_mode: nsamp=%u\n", (unsigned)st->nsamp);

	/* initialize decoder state, but don't overwrite nsamp */
	info("ilbc: calling initDecode(mode=%d)\n", mode);
	initDecode(&st->dec, mode, USE_ENHANCER);
	info("ilbc: initDecode completed (mode=%d)\n", mode);

	/* sanity check */
	if (st->nsamp != BLOCKL_20MS && st->nsamp != BLOCKL_30MS) {
		warning("ilbc: unexpected nsamp=%u after set_decoder_mode\n",
			(unsigned)st->nsamp);
	}
}


static void encoder_fmtp_decode(struct auenc_state *st, const char *fmtp)
{
	struct pl mode;

	if (!fmtp)
		return;

	if (re_regex(fmtp, strlen(fmtp), "mode=[0-9]+", &mode))
		return;
	{
		uint32_t m = pl_u32(&mode);
		/* Conservative: do not immediately switch to 30ms solely on remote SDP,
		 * because some peers mis-advertise (fmtp=30) while sending 20ms RTP.
		 * Keep encoder at current/default (20ms) until payload-length detection
		 * confirms remote's actual packetization.
		 */
		if (m == 30 && st->mode != 30) {
			info("ilbc: encoder_fmtp_decode: defer switching to 30ms until confirmed by RTP\n");
			/* Optionally remember desired mode here if needed */
		}
		else {
			set_encoder_mode(st, m);
		}
	}
}


static void decoder_fmtp_decode(struct audec_state *st, const char *fmtp)
{
	struct pl mode;

	if (!fmtp)
		return;

	if (re_regex(fmtp, strlen(fmtp), "mode=[0-9]+", &mode))
		return;

	set_decoder_mode(st, pl_u32(&mode));
}


static void encode_destructor(void *arg)
{
	struct auenc_state *st = arg;
	/* Clear global pointer if this encoder is being destroyed */
	if (g_aenc == st)
		g_aenc = NULL;
}


static void decode_destructor(void *arg)
{
	struct audec_state *st = arg;
	/* Remove detection state for this decoder if any */
	det_remove(st);
	(void)st;
}

/*
static int check_ptime(const struct auenc_param *prm)
{
	if (!prm)
		return 0;

	switch (prm->ptime) {

	case 20:
	case 30:
		return 0;

	default:
		warning("ilbc: invalid ptime %u ms\n", prm->ptime);
		return EINVAL;
	}
}
*/

static int encode_update(struct auenc_state **aesp, const struct aucodec *ac,
			 struct auenc_param *prm, const char *fmtp)
{
	struct auenc_state *st;

	if (!aesp || !ac || !prm)
		return EINVAL;
	//	if (check_ptime(prm))
	//		return EINVAL;
	info("ilbc: encode_update called aesp=%p fmtp=%s\n", (void *)*aesp, fmtp?fmtp:"(null)");

	/* If encoder already exists, apply fmtp changes (if any) and update global pointer */
	if (*aesp) {
		if (str_isset(fmtp)) {
			info("ilbc: encode_update applying fmtp to existing encoder: %s\n", fmtp);
			encoder_fmtp_decode(*aesp, fmtp);
		}
		g_aenc = *aesp;
		return 0;
	}

	st = mem_zalloc(sizeof(*st), encode_destructor);
	if (!st)
		return ENOMEM;

	set_encoder_mode(st, DEFAULT_MODE);

	if (str_isset(fmtp))
		encoder_fmtp_decode(st, fmtp);

	/* update parameters after SDP was decoded */
//	if (prm) {
//		prm->ptime = st->mode;
//	}

	*aesp = st;
	/* remember encoder globally so decoder-side detection can adjust it if peer lied */
	g_aenc = st;

	return 0;
}


static int decode_update(struct audec_state **adsp,
			 const struct aucodec *ac, const char *fmtp)
{
	struct audec_state *st;

	if (!adsp || !ac)
		return EINVAL;

	info("ilbc: decode_update called adsp=%p fmtp=%s\n", (void *)*adsp, fmtp?fmtp:"(null)");

	/* If decoder already exists, apply fmtp changes (if any) */
	if (*adsp) {
		if (str_isset(fmtp)) {
			info("ilbc: decode_update applying fmtp to existing decoder: %s\n", fmtp);
			decoder_fmtp_decode(*adsp, fmtp);
		}
		return 0;
	}

	st = mem_zalloc(sizeof(*st), decode_destructor);
	if (!st)
		return ENOMEM;

	set_decoder_mode(st, DEFAULT_MODE);

	if (str_isset(fmtp))
		decoder_fmtp_decode(st, fmtp);

	/* create detection state for this decoder */
	if (!det_find(st))
		det_add(st);

	*adsp = st;

	return 0;
}


static int encode(struct auenc_state *st, bool *marker, uint8_t *buf,
		  size_t *len, int fmt, const void *sampv, size_t sampc)
{
	float float_buf[sampc];
	uint32_t i;
	(void)marker;

	/* Make sure there is enough space */
	if (*len < st->enc_bytes) {
		warning("ilbc: encode: buffer is too small (%u bytes)\n",
			*len);
		return ENOMEM;
	}

	if (fmt != AUFMT_S16LE)
		return ENOTSUP;

	/* Convert from 16-bit samples to float */
	for (i=0; i<sampc; i++) {
		const int16_t v = ((int16_t *)sampv)[i];
		float_buf[i] = (float)v;
	}

	iLBC_encode(buf,            /* (o) encoded data bits iLBC */
		    float_buf,      /* (o) speech vector to encode */
		    &st->enc);      /* (i/o) the general encoder state */

	*len = st->enc_bytes;

	info("ilbc: encode called mode=%d enc_bytes=%u sampc=%zu -> pkt_len=%u\n",
	     st->mode, (unsigned)st->enc_bytes, sampc, (unsigned)*len);

	return 0;
}


static int do_dec(struct audec_state *st, int16_t *sampv, size_t *sampc,
		  const uint8_t *buf, size_t len)
{
	float float_buf[st->nsamp];
	const int mode = len ? 1 : 0;
	uint32_t i;

	/* Make sure there is enough space in the buffer */
	if (*sampc < st->nsamp) {
		warning("ilbc: do_dec: insuf buf: sampc_in=%zu nsamp=%u\n",
			*sampc, (unsigned)st->nsamp);
		return ENOMEM;
	}

	iLBC_decode(float_buf,      /* (o) decoded signal block */
		    (uint8_t *)buf, /* (i) encoded signal bits */
		    &st->dec,       /* (i/o) the decoder state structure */
		    mode);          /* (i) 0: bad packet, PLC, 1: normal */

	/* Convert from float to 16-bit samples */
	for (i=0; i<st->nsamp; i++) {
		sampv[i] = (int16_t)float_buf[i];
	}

	*sampc = st->nsamp;

	info("ilbc: do_dec done produced %u samples\n", (unsigned)*sampc);

	return 0;
}


static int decode(struct audec_state *st, int fmt, void *sampv,
		  size_t *sampc, bool marker, const uint8_t *buf, size_t len)
{
	(void)marker;

	if (fmt != AUFMT_S16LE)
		return ENOTSUP;

	info("ilbc: decode called fmt=%d buf_len=%zu dec_bytes=%zu nsamp=%u\n",
	     fmt, len, (size_t)st->dec_bytes, (unsigned)st->nsamp);

	/* Try to detect mode by payload length */
	if (st->dec_bytes != len) {

		st->dec_bytes = len;

		switch (st->dec_bytes) {

		case NO_OF_BYTES_20MS:
			set_decoder_mode(st, 20);
			break;

		case NO_OF_BYTES_30MS:
			set_decoder_mode(st, 30);
			break;

		default:
			warning("ilbc: decode: expect %u or %u, got %zu\n",
				(unsigned)NO_OF_BYTES_20MS, (unsigned)NO_OF_BYTES_30MS,
				len);
			return EINVAL;
		}

		/* Debounced confirmation: require a small number of consecutive
		 * detections of the same mode before switching our encoder. We
		 * keep per-decoder detection state in det_list (see above) since we
		 * cannot modify audec_state.
		 */
		{
			struct detect_node *dn = det_find(st);
			if (!dn)
				dn = det_add(st);

			if (g_aenc && g_aenc->mode != st->mode) {
				if (dn->detected_mode == st->mode) {
					dn->count++;
				}
				else {
					dn->detected_mode = st->mode;
					dn->count = 1;
				}

				/* require 2 consecutive packets to confirm */
				if (dn->count >= 2) {
					info("ilbc: confirmed remote payload mode %dms after %d pkts, adjusting encoder\n",
					     st->mode, dn->count);
					set_encoder_mode(g_aenc, st->mode);
					dn->detected_mode = 0;
					dn->count = 0;
				}
			}
		}
	}

	info("ilbc: calling do_dec nsamp=%u sampc_in=%zu len=%zu\n",
	     (unsigned)st->nsamp, sampc ? *sampc : 0, len);

	return do_dec(st, (int16_t *)sampv, sampc, buf, len);
}


static int pkloss(struct audec_state *st, int fmt, void *sampv,
		  size_t *sampc, const uint8_t *buf, size_t len)
{
	(void)buf;
	(void)len;

	if (fmt != AUFMT_S16LE)
		return ENOTSUP;

	return do_dec(st, (int16_t *)sampv, sampc, NULL, 0);
}


static struct aucodec ilbc = {
	.name    = "iLBC",
	.srate   = 8000,
	.crate   = 8000,
	.ch      = 1,
	.pch     = 1,
	.fmtp    = ilbc_fmtp,
	.encupdh = encode_update,
	.ench    = encode,
	.decupdh = decode_update,
	.dech    = decode,
	.plch    = pkloss,
};


static int module_init(void)
{
	(void)re_snprintf(ilbc_fmtp, sizeof(ilbc_fmtp),
		  "mode=%d", DEFAULT_MODE);

	taucodec_register(baresip_aucodecl(), &ilbc);
	return 0;
}


static int module_close(void)
{
	taucodec_unregister(&ilbc);
	return 0;
}


EXPORT_SYM const struct mod_export DECL_EXPORTS(ilbc) = {
	"ilbc",
	"audio codec",
	module_init,
	module_close
};
