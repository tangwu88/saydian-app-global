package cc.saidian.saydian_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RingNamePolicyTest {
    @Test
    fun `confirmed R12 names retain model boundaries and LuckRing precedence`() {
        listOf("R12", " r12 ", "R12_fixture", "r12-fixture").forEach {
            assertTrue(it, RingNamePolicy.isQRingName(it))
            assertNull(it, RingNamePolicy.coolWearModel(it))
        }
        listOf("R120", "R123", "XR12", "custom-R12-tail", "R18", "R12-HR05").forEach {
            assertFalse(it, RingNamePolicy.isQRingName(it))
        }
        assertNotNull(RingNamePolicy.coolWearModel("R12-HR05"))
    }

    @Test
    fun `qring keywords match anywhere without a model suffix restriction`() {
        listOf("R8", "custom-r8-tail", "R80", "prefix-R21-other", "custom-r22-tail", "Q_fixture", "O_fixture").forEach {
            assertTrue(it, RingNamePolicy.isQRingName(it))
            assertNull(it, RingNamePolicy.coolWearModel(it))
        }
    }

    @Test
    fun `luckring keywords include arbitrary prefixes and suffixes`() {
        listOf("HR01", "HR05", "K80", "R7", "K800", "R70", "R7Pro Max", "R7Ultra-other", "HR05X", "custom-hr01-tail", "custom-R7-tail").forEach {
            assertNotNull(it, RingNamePolicy.coolWearModel(it))
            assertFalse(it, RingNamePolicy.isQRingName(it))
        }
        assertEquals("R7Pro", RingNamePolicy.coolWearModel("custom-r7pro-max"))
        assertEquals("R7Ultra", RingNamePolicy.coolWearModel("custom-r7ultra-tail"))
    }

    @Test
    fun `luckring precedence prevents duplicate qring discovery`() {
        listOf("Q_HR01", "R8-HR05", "R21-R7", "R22-K80").forEach {
            assertNotNull(it, RingNamePolicy.coolWearModel(it))
            assertFalse(it, RingNamePolicy.isQRingName(it))
        }
    }

    @Test
    fun `unrelated and missing names do not select a ring sdk`() {
        listOf(null, "", "LUCKRING", "HR04", "K79", "R6", "R9", "SD-Watch-W9", "W8").forEach {
            assertNull(RingNamePolicy.coolWearModel(it))
            assertFalse(RingNamePolicy.isQRingName(it))
        }
    }
}
