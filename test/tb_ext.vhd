    wait for gCLK_HPER * 2;
    -- Expect: s_oQ to be $00000007

    -- Test Case 5:
    s_iD <= b"100000000111";
    s_inZero_Sign <= '0';
    wait for gCLK_HPER * 2;
    -- Expect: s_oQ to be $00000407

    -- Test Case 6:
    s_iD <= b"100000000111";
    s_inZero_Sign <= '1';
    wait for gCLK_HPER * 2;
    -- Expect: s_oQ to be $FFFFFC07

    -- Test Case 7:
    s_iD <= b"100000000111";
