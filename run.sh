#!/bin/bash
# First check that Leo is installed.
if ! command -v leo &> /dev/null
then
    echo "leo is not installed."
    exit
fi


echo "
###############################################
#                                             #
#         stake_token                         #
#                                             #
###############################################
"
leo run stake_token aleo1eavacq46a7tqm9ec0kyelvmun6qlxyquhrfv6aza82jnmljsp5yq52xvxt 150u64



echo "
###############################################
#                                             #
#         start_voting_campaign               #
#                                             #
###############################################
"
leo run start_voting_campaign aleo1eavacq46a7tqm9ec0kyelvmun6qlxyquhrfv6aza82jnmljsp5yq52xvxt 1231231field

echo "
###############################################
#                                             #
#         vote agree                          #
#                                             #
###############################################
"

leo run agree 

echo "
###############################################
#                                             #
#         vote disagree                       #
#                                             #
###############################################
"

leo run disagree

echo "
###############################################
#                                             #
#         award amount                        #
#                                             #
###############################################
"

leo run award_amount

