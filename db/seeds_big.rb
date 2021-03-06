  FIRST_NAMES=["Noble","Linus","Blake","Justin","Myles","Grady","Nero","Walter","Hoyt","Amir","Carlos","Murphy","Brent","Dalton","Dane","Mohammad","Palmer","Chandler","Nicholas","Armando","Chaim","Peter","Upton","Jonas","Todd","Kenyon","Eagan","Baxter","Kane","Abel","Hashim","Ralph","Aidan","Armand","Norman","Cadman","Kibo","Rigel","Lionel","Troy","Vernon","Levi","Quentin","Murphy","Armando","Cade","Gil","Nasim","Vaughan","Cairo","Tate","Kenneth","Conan","Aaron","Palmer","Gregory","Griffith","Wade","Peter","Jordan","Ezra","Emery","Louis","Carl","Raphael","Cruz","Macaulay","Carl","Colin","Paki","Basil","Mason","Christopher","Nathaniel","Davis","Ralph","Valentine","Fritz","Callum","Burton","Sylvester","Malcolm","Clayton","Gregory","Abdul","Guy","Elvis","Laith","Nigel","James","Kadeem","Lamar","Harding","Arden","Jeremy","Kasimir","Knox","Ulric","Andrew","Dalton","Jakeem","Cadman","Phelan","Forrest","Arsenio","Hu","Camden","Bernard","Amir","Channing","Fulton","William","Xenos","Quentin","Cole","Barrett","Nathan","Kamal","Zephania","Walter","Rahim","Merrill","Jacob","Kasimir","Wallace","Bradley","Jasper","Dominic","Wyatt","Jerome","Blaze","Troy","Scott","Dieter","Gary","Todd","Marsden","Bruno","Galvin","Nero","Holmes","Magee","Todd","Hop","Alden","Arsenio","Kirk","Wayne","Herman","Dieter","Ivan","Aladdin","Rahim","Elliott","Steven","Jakeem","Steel","Drew","Bernard","Lyle","Palmer","Dean","Myles","Raja","Igor","Zeph","Denton","Brennan","Chaim","Cruz","Isaiah","Garrison","Thomas","Brendan","Hilel","Brian","Ivor","Kareem","Louis","Ethan","Harding","Barry","Fitzgerald","Quinlan","Marsden","Kyle","Phillip","James","Matthew","Marsden","Grady","Ethan","Ciaran","Barclay","Dalton","Wing","Phelan","Geoffrey","Deacon","Marshall"]
  LAST_NAMES=["Myers","Craig","Harris","Cook","Houston","Goff","Hurley","Montoya","Combs","Collier","Pittman","Albert","Evans","Marsh","Branch","Wolf","Galloway","Spencer","Prince","Hess","Ingram","Todd","Perez","Harvey","Mccormick","Boone","Ferguson","Horn","Glenn","Sandoval","Pacheco","Contreras","Woods","Pratt","Bush","Vance","Vance","Lang","Gordon","Love","King","Dudley","Peters","Giles","Parrish","Kline","Watkins","Hill","Rich","Nguyen","Fry","Joseph","Haynes","Stanton","Valenzuela","Owen","Barrera","Cook","Morrison","Scott","Ortega","Rasmussen","Barker","Maynard","George","Ortiz","Schneider","Suarez","Clark","Wise","Chapman","Knapp","Meyers","Wilcox","Dodson","Mercado","Cabrera","Maxwell","Lott","Whitney","Harrell","Lee","Sexton","Hooper","Chang","Branch","Bradshaw","Lindsay","Franks","Woodard","Ford","Justice","William","Mcgowan","Craig","Harvey","Daniel","Sanders","Gibson","Becker","Nixon","Sellers","Reese","Joyce","Steele","Mercado","Blackwell","Mckee","Chang","Mason","Reeves","Wiley","Swanson","Baird","Banks","Phelps","Dillard","James","Vasquez","Bentley","Hines","Wheeler","Rogers","Luna","Reese","Gamble","Blevins","Kelley","Blankenship","Combs","Mcmillan","Sargent","James","Simon","Dixon","Cline","Mcdowell","Chapman","Parks","Garza","Sellers","Wilkinson","Watson","Stevenson","Woodard","Cantrell","Wolf","Horn","Dorsey","Short","Cooke","Castillo","Charles","Chen","Barber","Garrison","Casey","Rivas","Richardson","Caldwell","Pennington","Gomez","Delacruz","Carver","Bond","Wiley","Ashley","Bishop","Howe","Beck","Pruitt","Good","Oneill","Acevedo","Rivera","Crane","Henderson","Colon","Gonzales","Burke","Giles","Paul","Curry","Lowe","Avila","Carver","Woodward","Nguyen","Mills","Caldwell","Roy","Taylor","Tillman","Simmons","Hodges","Odonnell","Bean","Burt","Clayton","Walls"]
 
promotion = Promotion.first
=begin
1000.times do
  fn = FIRST_NAMES.shuffle.first
  ln = LAST_NAMES.shuffle.first
  user = promotion.users.build
  user.role = User::Role[:user]
  user.password = 'test'
  user.email = "#{fn.downcase}.#{ln.downcase}@test.hesonline.com"
  next if !User.find_by_email(user.email).nil?
  user.auth_key = rand(9999999)
  user.username = "#{fn.downcase}#{ln.downcase}"
  user.save
  user_profile = user.create_profile :first_name => fn, :last_name => ln, :goal_steps => 6000, :goal_minutes => 30
  puts "created #{user.email}"
end
=end



promotion.users.each_with_index{|u,index|
  ds = Date.parse("2014-01-01")
  de = Date.parse("2014-12-31")
  (ds..de).each do |day|
    puts day
    steps = [*2000..12000].sample
    minutes = [*20..120].sample
    next if !u.entries.where(:recorded_on => day).empty?
    e = u.entries.create(:recorded_on => day, :exercise_steps => steps, :exercise_minutes => minutes)
    e.save!
    puts "User #{index}: #{day}"
  end
}