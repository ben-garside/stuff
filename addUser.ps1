Param(
    $username,
    $doamin
)

Add-LocalGroupMember -Group Administrators -Member "$domain\$username"
