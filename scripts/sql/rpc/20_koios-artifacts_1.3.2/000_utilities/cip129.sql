-- Binary format
--       1 byte     variable length
--      <------> <------------------->
--     ┌────────┬─────────────────────┐
--     │ header │        key          │
--     └────────┴─────────────────────┘
--         🔎
--         ╎          7 6 5 4 3 2 1 0
--         ╎         ┌─┬─┬─┬─┬─┬─┬─┬─┐
--         ╰╌╌╌╌╌╌╌╌ |t│t│t│t│c│c│c│c│
--                   └─┴─┴─┴─┴─┴─┴─┴─┘
--
-- Key Type (`t t t t . . . .`)          | Key
-- ---                                   | ---
-- `0000....`                            | CC Hot
-- `0001....`                            | CC Cold
-- `0010....`                            | DRep
--
-- Credential Type (`. . . . c c c c`)   | Semantic
-- ---                                   | ---
-- `....0010`                            | Key Hash
-- `....0011`                            | Script Hash

CREATE OR REPLACE FUNCTION grest.cip129_cc_hot_to_hex(_cc_hot text)
RETURNS text
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  IF LENGTH(_cc_hot) = 60 THEN
    RETURN SUBSTRING(ENCODE(cardano.bech32_decode_data(_cc_hot),'hex') from 3);
  ELSE
    RETURN ENCODE(cardano.bech32_decode_data(_cc_hot),'hex');
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION grest.cip129_cc_hot_has_script(_cc_hot text)
RETURNS boolean
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  IF LENGTH(_cc_hot) = 60 THEN
    RETURN SUBSTRING(ENCODE(cardano.bech32_decode_data(_cc_hot),'hex') from 2 for 1) = '3';
  ELSE
    RETURN STARTS_WITH(_cc_hot, 'cc_hot_script');
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION grest.cip129_hex_to_cc_hot(_raw bytea, _is_script boolean)
RETURNS text
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  IF _raw IS NULL THEN RETURN NULL; END IF;
  IF _is_script THEN
    RETURN cardano.bech32_encode('cc_hot', ('\x03'::bytea || _raw));
  ELSE
    RETURN cardano.bech32_encode('cc_hot', ('\x02'::bytea || _raw));
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION grest.cip129_cc_cold_to_hex(_cc_cold text)
RETURNS text
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  IF LENGTH(_cc_cold) = 61 THEN
    RETURN SUBSTRING(ENCODE(cardano.bech32_decode_data(_cc_cold),'hex') from 3);
  ELSE
    RETURN ENCODE(cardano.bech32_decode_data(_cc_cold),'hex');
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION grest.cip129_cc_cold_has_script(_cc_cold text)
RETURNS boolean
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  IF LENGTH(_cc_cold) = 61 THEN
    RETURN SUBSTRING(ENCODE(cardano.bech32_decode_data(_cc_cold),'hex') from 2 for 1) = '3';
  ELSE
    RETURN STARTS_WITH(_cc_cold, 'cc_cold_script');
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION grest.cip129_hex_to_cc_cold(_raw bytea, _is_script boolean)
RETURNS text
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  IF _raw IS NULL THEN RETURN NULL; END IF;
  IF _is_script THEN
    RETURN cardano.bech32_encode('cc_cold', ('\x13'::bytea || _raw));
  ELSE
    RETURN cardano.bech32_encode('cc_cold', ('\x12'::bytea || _raw));
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION grest.cip129_drep_id_to_hex(_drep_id text)
RETURNS text
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  IF LENGTH(_drep_id) = 58 THEN
    RETURN SUBSTRING(ENCODE(cardano.bech32_decode_data(_drep_id),'hex') from 3);
  ELSE
    RETURN ENCODE(cardano.bech32_decode_data(_drep_id),'hex');
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION grest.cip129_drep_id_has_script(_drep_id text)
RETURNS boolean
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  IF LENGTH(_drep_id) = 58 THEN
    RETURN SUBSTRING(ENCODE(cardano.bech32_decode_data(_drep_id),'hex') from 2 for 1) = '3';
  ELSE
    RETURN STARTS_WITH(_drep_id, 'drep_script');
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION grest.cip129_hex_to_drep_id(_raw bytea, _is_script boolean)
RETURNS text
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  IF _raw IS NULL THEN RETURN NULL; END IF;
  IF _is_script THEN
    RETURN cardano.bech32_encode('drep', ('\x23'::bytea || _raw));
  ELSE
    RETURN cardano.bech32_encode('drep', ('\x22'::bytea || _raw));
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION grest.cip129_from_gov_action_id(_proposal_id text)
RETURNS text []
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  proposal_id_hex text;
BEGIN
  SELECT INTO proposal_id_hex ENCODE(cardano.bech32_decode_data(_proposal_id),'hex');
  RETURN ARRAY[LEFT(proposal_id_hex, 64), ('x' || RIGHT(proposal_id_hex, -64))::bit(8)::int::text];
END;
$$;

CREATE OR REPLACE FUNCTION grest.cip129_to_gov_action_id(_tx_hash bytea, _index bigint)
RETURNS text
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  RETURN cardano.bech32_encode('gov_action', (_tx_hash || DECODE(LPAD(TO_HEX(_index), 2, '0'), 'hex')));
END;
$$;

COMMENT ON FUNCTION grest.cip129_cc_hot_to_hex IS 'Returns binary hex from Constitutional Committee Hot Credential ID in old or new (CIP-129) format'; -- noqa: LT01
COMMENT ON FUNCTION grest.cip129_cc_hot_has_script IS 'Returns true if Constitutional Committee Hot Credential ID is of type script'; -- noqa: LT01
COMMENT ON FUNCTION grest.cip129_hex_to_cc_hot IS 'Returns Constitutional Committee Hot Credential ID in CIP-129 format from raw binary hex'; -- noqa: LT01
COMMENT ON FUNCTION grest.cip129_cc_cold_to_hex IS 'Returns binary hex from Constitutional Committee Cold Credential ID in old or new (CIP-129) format'; -- noqa: LT01
COMMENT ON FUNCTION grest.cip129_cc_cold_has_script IS 'Returns true if Constitutional Committee Cold Credential ID is of type script'; -- noqa: LT01
COMMENT ON FUNCTION grest.cip129_hex_to_cc_cold IS 'Returns Constitutional Committee Cold Credential ID in CIP-129 format from raw binary hex'; -- noqa: LT01
COMMENT ON FUNCTION grest.cip129_drep_id_to_hex IS 'Returns binary hex from DRep Credential ID in old or new (CIP-129) format'; -- noqa: LT01
COMMENT ON FUNCTION grest.cip129_drep_id_has_script IS 'Returns true if DRep Credential ID is of type script'; -- noqa: LT01
COMMENT ON FUNCTION grest.cip129_hex_to_drep_id IS 'Returns DRep Credential ID in CIP-129 format from raw binary hex'; -- noqa: LT01
COMMENT ON FUNCTION grest.cip129_from_gov_action_id IS 'Returns string array containing transaction hash and certificate index from Governance Action Proposal ID in CIP-129 format'; -- noqa: LT01
COMMENT ON FUNCTION grest.cip129_to_gov_action_id IS 'Returns Governance Action Proposal ID in CIP-129 format from transaction hash appended by index of certificate within the transaction'; -- noqa: LT01
