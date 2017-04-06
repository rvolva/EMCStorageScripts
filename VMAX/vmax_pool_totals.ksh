awk '	( /SATAR6/ ) { print $0;R6total+=$4;R6free+=$5 } 
	( /FC.*R5/ ) { print $0; R5total+=$4; R5free+=$5} 
	( /EFD/ ) { print $0; EFDtotal+=$4; EFDfree+=$5} 
	( /FC.*R1/ ) { print $0; R1total+=$5; R1free+=$6} 

	END {
		printf "%10s  %10s %10s %3s\n", "POOL","TOTAL GB","FREE GB","USED";
		if( EFDtotal !=0 ) { printf "%10s: %10d %10d %2d%\n","EFD",EFDtotal,EFDfree,(1-EFDfree/EFDtotal)*100; }
		if( R1total !=0 ) { printf "%10s: %10d %10d %2d%\n","FC_R1",R1total,R1free,(1-R1free/R1total)*100; }
		if( R5total !=0 ) { printf "%10s: %10d %10d %2d%\n","FC_R5",R5total,R5free,(1-R5free/R5total)*100; }
		if( R6total !=0 ) { printf "%10s: %10d %10d %2d%\n","SATAR6",R6total,R6free,(1-R6free/R6total)*100; }

	}
'
